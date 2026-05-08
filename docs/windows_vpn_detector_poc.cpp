// windows_vpn_detector_poc.cpp
//
// Proof-of-concept Windows scanner for programs that may detect VPN/proxy/Tor.
//
// What it does:
//   - inventories installed apps from Uninstall registry keys;
//   - adds currently running process directories;
//   - optionally scans common system application directories or custom paths;
//   - scans EXE/DLL/.NET/Electron/JS-like files for:
//       * PE imports: RAS, IP Helper, WinHTTP/WinINet proxy APIs;
//       * strings: VPN adapter names, proxy registry keys, telemetry fields,
//         Tor/VPN client names, WMI network adapter queries;
//   - scores findings by combinations, not by a single weak token.
//
// This is a static PoC, not an EDR and not a proof of data exfiltration.
// A "high" score means "contains strong signs of VPN/proxy discovery logic".
//
// Build with MSVC:
//   cl /std:c++17 /EHsc /O2 windows_vpn_detector_poc.cpp /link Advapi32.lib
//
// Build with MinGW:
//   g++ -std=c++17 -O2 -municode windows_vpn_detector_poc.cpp -ladvapi32 -o vpnscan.exe
//
// Examples:
//   vpnscan.exe
//   vpnscan.exe --full --min-score 50
//   vpnscan.exe --full --exe-only --min-score 50
//   vpnscan.exe --path "C:\Users\you\AppData\Local\Programs"
//   vpnscan.exe --max-file-mb 80 --max-files-per-root 2000

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <tlhelp32.h>

#include <algorithm>
#include <cctype>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <cwctype>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <map>
#include <optional>
#include <set>
#include <sstream>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace fs = std::filesystem;

enum FindingFlag : uint32_t {
    RAS_API       = 1u << 0,
    ADAPTER_API   = 1u << 1,
    PROXY_API     = 1u << 2,
    PROXY_CONFIG  = 1u << 3,
    RASPHONE      = 1u << 4,
    VPN_CLIENT    = 1u << 5,
    VPN_TELEMETRY = 1u << 6,
    TOR_SIGNAL    = 1u << 7,
    WMI_ADAPTER   = 1u << 8,
    GENERIC_VPN   = 1u << 9,
};

struct Indicator {
    std::string label;
    std::vector<std::string> needles;
    uint32_t flag;
};

struct ScanOptions {
    bool full = false;
    bool exeOnly = false;
    bool json = false;
    bool pathsOnly = false;
    bool runningOnly = false;
    uint64_t maxFileBytes = 150ull * 1024ull * 1024ull;
    size_t maxFilesPerRoot = 5000;
    int maxDepth = -1;
    int minScore = 20;
    std::vector<fs::path> customPaths;
};

struct ScanRoot {
    std::wstring name;
    fs::path root;
    std::wstring source;
};

struct FileFinding {
    fs::path file;
    uint32_t flags = 0;
    std::map<std::string, std::vector<std::string>> examples;

    void add(uint32_t flag, const std::string& label, const std::string& example) {
        flags |= flag;
        auto& bucket = examples[label];
        if (bucket.size() < 4) {
            bucket.push_back(example.substr(0, 220));
        }
    }
};

struct AppFinding {
    ScanRoot root;
    uint32_t flags = 0;
    int score = 0;
    size_t scannedFiles = 0;
    std::vector<fs::path> executableCandidates;
    std::vector<FileFinding> files;
};

static std::wstring WidenAscii(const std::string& s) {
    std::wstring out;
    out.reserve(s.size());
    for (unsigned char c : s) out.push_back(static_cast<wchar_t>(c));
    return out;
}

static std::wstring ToLowerW(std::wstring s) {
    std::transform(s.begin(), s.end(), s.begin(), [](wchar_t c) {
        return static_cast<wchar_t>(towlower(c));
    });
    return s;
}

static std::string ToLowerAscii(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return s;
}

static std::wstring ExpandEnv(const std::wstring& s) {
    DWORD needed = ExpandEnvironmentStringsW(s.c_str(), nullptr, 0);
    if (!needed) return s;
    std::wstring out(needed, L'\0');
    DWORD written = ExpandEnvironmentStringsW(s.c_str(), out.data(), needed);
    if (!written) return s;
    if (!out.empty() && out.back() == L'\0') out.pop_back();
    return out;
}

static bool ExistsDir(const fs::path& p) {
    std::error_code ec;
    return fs::exists(p, ec) && fs::is_directory(p, ec);
}

static bool ExistsFile(const fs::path& p) {
    std::error_code ec;
    return fs::exists(p, ec) && fs::is_regular_file(p, ec);
}

static bool IsPathUnder(const fs::path& path, const fs::path& base) {
    if (path.empty() || base.empty()) return false;

    std::error_code ec;
    fs::path normalizedPath = fs::weakly_canonical(path, ec);
    if (ec) normalizedPath = fs::absolute(path, ec);
    ec.clear();
    fs::path normalizedBase = fs::weakly_canonical(base, ec);
    if (ec) normalizedBase = fs::absolute(base, ec);

    std::wstring pathText = ToLowerW(normalizedPath.wstring());
    std::wstring baseText = ToLowerW(normalizedBase.wstring());
    while (!pathText.empty() && (pathText.back() == L'\\' || pathText.back() == L'/')) pathText.pop_back();
    while (!baseText.empty() && (baseText.back() == L'\\' || baseText.back() == L'/')) baseText.pop_back();
    if (pathText == baseText) return true;
    if (pathText.size() <= baseText.size()) return false;
    wchar_t separator = pathText[baseText.size()];
    return pathText.rfind(baseText, 0) == 0 && (separator == L'\\' || separator == L'/');
}

static bool IsWindowsSystemRoot(const fs::path& root) {
    wchar_t windowsDir[MAX_PATH * 4];
    UINT length = GetWindowsDirectoryW(windowsDir, static_cast<UINT>(std::size(windowsDir)));
    if (!length || length >= static_cast<UINT>(std::size(windowsDir))) return false;
    return IsPathUnder(root, fs::path(windowsDir));
}

static std::wstring RegReadString(HKEY key, const wchar_t* valueName) {
    DWORD type = 0;
    DWORD bytes = 0;
    LONG rc = RegQueryValueExW(key, valueName, nullptr, &type, nullptr, &bytes);
    if (rc != ERROR_SUCCESS || bytes == 0) return L"";
    if (type != REG_SZ && type != REG_EXPAND_SZ) return L"";

    std::wstring value(bytes / sizeof(wchar_t), L'\0');
    rc = RegQueryValueExW(key, valueName, nullptr, &type,
                          reinterpret_cast<LPBYTE>(value.data()), &bytes);
    if (rc != ERROR_SUCCESS) return L"";
    while (!value.empty() && value.back() == L'\0') value.pop_back();
    if (type == REG_EXPAND_SZ) value = ExpandEnv(value);
    return value;
}

static std::optional<fs::path> ExtractPathFromCommandLike(std::wstring s) {
    if (s.empty()) return std::nullopt;
    s = ExpandEnv(s);

    auto trim = [](std::wstring& v) {
        while (!v.empty() && iswspace(v.front())) v.erase(v.begin());
        while (!v.empty() && iswspace(v.back())) v.pop_back();
    };
    trim(s);

    std::wstring candidate;
    if (!s.empty() && s.front() == L'"') {
        size_t end = s.find(L'"', 1);
        if (end != std::wstring::npos) candidate = s.substr(1, end - 1);
    } else {
        size_t exe = ToLowerW(s).find(L".exe");
        if (exe != std::wstring::npos) candidate = s.substr(0, exe + 4);
        else {
            size_t comma = s.find(L',');
            candidate = s.substr(0, comma == std::wstring::npos ? s.size() : comma);
            size_t space = candidate.find(L" /");
            if (space != std::wstring::npos) candidate = candidate.substr(0, space);
        }
    }

    trim(candidate);
    if (candidate.empty()) return std::nullopt;
    return fs::path(candidate);
}

static void AddRoot(std::vector<ScanRoot>& roots,
                    std::unordered_set<std::wstring>& seen,
                    std::wstring name,
                    fs::path root,
                    std::wstring source) {
    std::error_code ec;
    root = fs::weakly_canonical(root, ec);
    if (ec) root = fs::absolute(root, ec);
    std::wstring key = ToLowerW(root.wstring());
    if (key.empty() || seen.count(key)) return;
    if (!ExistsDir(root) && !ExistsFile(root)) return;
    if (source != L"--path" && IsWindowsSystemRoot(root)) return;
    seen.insert(key);
    roots.push_back({std::move(name), std::move(root), std::move(source)});
}

static void AddImmediateChildDirs(std::vector<ScanRoot>& roots,
                                  std::unordered_set<std::wstring>& seen,
                                  const fs::path& base,
                                  const std::wstring& source) {
    if (!ExistsDir(base)) return;
    std::error_code ec;
    fs::directory_iterator it(base, fs::directory_options::skip_permission_denied, ec);
    fs::directory_iterator end;
    while (!ec && it != end) {
        if (it->is_directory(ec) && !ec) {
            AddRoot(roots, seen, it->path().filename().wstring(), it->path(), source);
        }
        it.increment(ec);
    }
}

static void EnumerateUninstallKey(std::vector<ScanRoot>& roots,
                                  std::unordered_set<std::wstring>& seen,
                                  HKEY hive,
                                  const wchar_t* subkey,
                                  REGSAM view,
                                  const std::wstring& source) {
    HKEY key = nullptr;
    if (RegOpenKeyExW(hive, subkey, 0, KEY_READ | view, &key) != ERROR_SUCCESS) return;

    DWORD index = 0;
    wchar_t nameBuf[512];
    DWORD nameLen = 512;
    while (RegEnumKeyExW(key, index++, nameBuf, &nameLen, nullptr, nullptr, nullptr, nullptr) == ERROR_SUCCESS) {
        HKEY appKey = nullptr;
        if (RegOpenKeyExW(key, nameBuf, 0, KEY_READ | view, &appKey) == ERROR_SUCCESS) {
            std::wstring displayName = RegReadString(appKey, L"DisplayName");
            std::wstring installLocation = RegReadString(appKey, L"InstallLocation");
            std::wstring displayIcon = RegReadString(appKey, L"DisplayIcon");
            std::wstring uninstallString = RegReadString(appKey, L"UninstallString");

            fs::path root;
            if (!installLocation.empty()) {
                root = fs::path(installLocation);
            } else if (auto displayIconPath = ExtractPathFromCommandLike(displayIcon)) {
                root = displayIconPath->parent_path();
            } else if (auto uninstallPath = ExtractPathFromCommandLike(uninstallString)) {
                root = uninstallPath->parent_path();
            }

            if (!root.empty()) {
                if (displayName.empty()) displayName = nameBuf;
                AddRoot(roots, seen, displayName, root, source);
            }
            RegCloseKey(appKey);
        }
        nameLen = 512;
    }
    RegCloseKey(key);
}

static std::vector<ScanRoot> BuildScanRoots(const ScanOptions& opts) {
    std::vector<ScanRoot> roots;
    std::unordered_set<std::wstring> seen;

    if (!opts.pathsOnly) {
        if (!opts.runningOnly) {
            const wchar_t* uninstall = L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall";
            EnumerateUninstallKey(roots, seen, HKEY_LOCAL_MACHINE, uninstall, KEY_WOW64_64KEY, L"registry HKLM 64");
            EnumerateUninstallKey(roots, seen, HKEY_LOCAL_MACHINE, uninstall, KEY_WOW64_32KEY, L"registry HKLM 32");
            EnumerateUninstallKey(roots, seen, HKEY_CURRENT_USER, uninstall, 0, L"registry HKCU");
        }

        HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
        if (snap != INVALID_HANDLE_VALUE) {
            PROCESSENTRY32W pe{};
            pe.dwSize = sizeof(pe);
            if (Process32FirstW(snap, &pe)) {
                do {
                    HANDLE proc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pe.th32ProcessID);
                    if (!proc) continue;
                    wchar_t pathBuf[MAX_PATH * 4];
                    DWORD size = static_cast<DWORD>(std::size(pathBuf));
                    if (QueryFullProcessImageNameW(proc, 0, pathBuf, &size)) {
                        fs::path exe(pathBuf);
                        if (ExistsFile(exe)) {
                            AddRoot(roots, seen, pe.szExeFile, exe.parent_path(), L"running process");
                        }
                    }
                    CloseHandle(proc);
                } while (Process32NextW(snap, &pe));
            }
            CloseHandle(snap);
        }

        if (opts.full && !opts.runningOnly) {
            auto addEnvChildren = [&](const wchar_t* env, const wchar_t* suffix, const wchar_t* sourceName) {
                wchar_t buf[MAX_PATH * 4];
                DWORD n = GetEnvironmentVariableW(env, buf, static_cast<DWORD>(std::size(buf)));
                if (!n || n >= std::size(buf)) return;
                fs::path envPath(buf);
                if (suffix && *suffix) envPath /= suffix;
                AddImmediateChildDirs(roots, seen, envPath, sourceName);
            };
            addEnvChildren(L"ProgramFiles", L"", L"--full Program Files child");
            addEnvChildren(L"ProgramFiles(x86)", L"", L"--full Program Files x86 child");
            addEnvChildren(L"LocalAppData", L"Programs", L"--full LocalAppData Programs child");
            addEnvChildren(L"LocalAppData", L"", L"--full LocalAppData child");
        }
    }

    for (const auto& p : opts.customPaths) {
        AddRoot(roots, seen, p.filename().wstring(), p, L"--path");
    }

    return roots;
}

static const std::vector<Indicator>& Indicators() {
    static const std::vector<Indicator> indicators = {
        {"vpn telemetry field",
            {"is_vpn", "isvpn", "vpn_enabled", "vpnenabled", "isvpnconnected", "vpn_status", "vpnstatus", "proxy_detected"},
            VPN_TELEMETRY},
        {"vpn client/adapter string",
            {"wireguard", "wintun", "openvpn", "tap-windows", "tap0901", "nordlynx", "anyconnect",
             "cisco anyconnect", "forticlient", "globalprotect", "protonvpn", "tunnelbear", "tailscale", "zerotier"},
            VPN_CLIENT},
        {"generic vpn string",
            {"vpn", "virtual private network"},
            GENERIC_VPN},
        {"proxy config string",
            {"proxyenable", "proxyserver", "autoconfigurl", "proxyoverride", "winhttp proxy", "internet settings\\proxy"},
            PROXY_CONFIG},
        {"ras phonebook",
            {"rasphone.pbk", "\\network\\connections\\pbk", "microsoft\\network\\connections\\pbk"},
            RASPHONE},
        {"tor signal",
            {"tor browser", "torbrowser", "torproject"},
            TOR_SIGNAL},
        {"wmi adapter query",
            {"win32_networkadapter", "win32_networkadapterconfiguration", "win32_ip4routetable",
             "msft_netadapter", "select * from win32_networkadapter"},
            WMI_ADAPTER},
        {"adapter api string",
            {"getadaptersaddresses", "getadaptersinfo", "getiftable", "getiftable2", "getipforwardtable", "getipforwardtable2"},
            ADAPTER_API},
        {"ras api string",
            {"rasenumconnections", "rasgetconnectstatus", "rasenumentries", "rasgetentryproperties"},
            RAS_API},
        {"proxy api string",
            {"winhttpgetieproxyconfigforcurrentuser", "winhttpgetproxyforurl", "internetqueryoption"},
            PROXY_API},
        {".net network interface",
            {"system.net.networkinformation.networkinterface", "getallnetworkinterfaces", "networkinterface.getallnetworkinterfaces"},
            ADAPTER_API},
    };
    return indicators;
}

static bool HasFlag(uint32_t flags, uint32_t f) {
    return (flags & f) != 0;
}

static int ScoreFlags(uint32_t flags) {
    int score = 0;

    if (HasFlag(flags, RAS_API)) score += 40;
    if (HasFlag(flags, RASPHONE)) score += 35;
    if (HasFlag(flags, ADAPTER_API)) score += 15;
    if (HasFlag(flags, PROXY_API)) score += 15;
    if (HasFlag(flags, PROXY_CONFIG)) score += 15;
    if (HasFlag(flags, VPN_CLIENT)) score += 30;
    if (HasFlag(flags, VPN_TELEMETRY)) score += 25;
    if (HasFlag(flags, TOR_SIGNAL)) score += 25;
    if (HasFlag(flags, WMI_ADAPTER)) score += 25;
    if (HasFlag(flags, GENERIC_VPN)) score += 5;

    if (HasFlag(flags, ADAPTER_API) && HasFlag(flags, VPN_CLIENT)) score += 25;
    if (HasFlag(flags, ADAPTER_API) && HasFlag(flags, GENERIC_VPN)) score += 15;
    if (HasFlag(flags, PROXY_API) && HasFlag(flags, VPN_TELEMETRY)) score += 20;
    if (HasFlag(flags, PROXY_CONFIG) && HasFlag(flags, VPN_TELEMETRY)) score += 20;
    if (HasFlag(flags, WMI_ADAPTER) && (HasFlag(flags, GENERIC_VPN) || HasFlag(flags, VPN_CLIENT))) score += 20;
    if ((HasFlag(flags, RAS_API) || HasFlag(flags, RASPHONE)) && HasFlag(flags, VPN_TELEMETRY)) score += 25;

    return score;
}

static std::wstring LabelForScore(int score) {
    if (score >= 100) return L"critical: VPN/proxy discovery + telemetry-like signals";
    if (score >= 80) return L"spyware-like VPN discovery signals";
    if (score >= 50) return L"likely detects VPN/proxy";
    if (score >= 20) return L"suspicious";
    return L"weak";
}

static std::wstring FlagsToText(uint32_t flags) {
    std::vector<std::wstring> parts;
    if (HasFlag(flags, RAS_API)) parts.push_back(L"RAS API");
    if (HasFlag(flags, ADAPTER_API)) parts.push_back(L"adapter API");
    if (HasFlag(flags, PROXY_API)) parts.push_back(L"proxy API");
    if (HasFlag(flags, PROXY_CONFIG)) parts.push_back(L"proxy config");
    if (HasFlag(flags, RASPHONE)) parts.push_back(L"rasphone.pbk");
    if (HasFlag(flags, VPN_CLIENT)) parts.push_back(L"VPN client/adapter strings");
    if (HasFlag(flags, VPN_TELEMETRY)) parts.push_back(L"VPN telemetry fields");
    if (HasFlag(flags, TOR_SIGNAL)) parts.push_back(L"Tor strings");
    if (HasFlag(flags, WMI_ADAPTER)) parts.push_back(L"WMI adapter query");
    if (HasFlag(flags, GENERIC_VPN)) parts.push_back(L"generic vpn");

    std::wstringstream ss;
    for (size_t i = 0; i < parts.size(); ++i) {
        if (i) ss << L", ";
        ss << parts[i];
    }
    return ss.str();
}

template <typename T>
static bool ReadStruct(const std::vector<uint8_t>& data, size_t off, T& out) {
    if (off > data.size() || sizeof(T) > data.size() - off) return false;
    memcpy(&out, data.data() + off, sizeof(T));
    return true;
}

static std::optional<size_t> RvaToOffset(DWORD rva, const std::vector<IMAGE_SECTION_HEADER>& sections) {
    for (const auto& sec : sections) {
        DWORD start = sec.VirtualAddress;
        DWORD span = std::max(sec.Misc.VirtualSize, sec.SizeOfRawData);
        DWORD end = start + span;
        if (rva >= start && rva < end) {
            return static_cast<size_t>(sec.PointerToRawData + (rva - start));
        }
    }
    return std::nullopt;
}

static std::string ReadCString(const std::vector<uint8_t>& data, size_t off, size_t maxLen = 4096) {
    std::string s;
    if (off >= data.size()) return s;
    size_t end = std::min(data.size(), off + maxLen);
    for (size_t i = off; i < end && data[i] != 0; ++i) {
        unsigned char c = data[i];
        if (c < 0x20 || c > 0x7e) break;
        s.push_back(static_cast<char>(c));
    }
    return s;
}

static void MatchTextIndicators(const std::string& raw, FileFinding& finding) {
    std::string lower = ToLowerAscii(raw);
    for (const auto& ind : Indicators()) {
        for (const auto& needle : ind.needles) {
            if (lower.find(needle) != std::string::npos) {
                finding.add(ind.flag, ind.label, raw);
                break;
            }
        }
    }
}

static void AddImportFinding(const std::string& dll, const std::string& fn, FileFinding& finding) {
    std::string d = ToLowerAscii(dll);
    std::string f = ToLowerAscii(fn);
    std::string example = dll + "!" + fn;

    if (d == "rasapi32.dll" &&
        (f.find("rasenumconnections") != std::string::npos ||
         f.find("rasgetconnectstatus") != std::string::npos ||
         f.find("rasenumentries") != std::string::npos ||
         f.find("rasgetentryproperties") != std::string::npos)) {
        finding.add(RAS_API, "PE import: RAS VPN API", example);
    }

    if (d == "iphlpapi.dll" &&
        (f.find("getadaptersaddresses") != std::string::npos ||
         f.find("getadaptersinfo") != std::string::npos ||
         f.find("getiftable") != std::string::npos ||
         f.find("getipforwardtable") != std::string::npos ||
         f.find("getnetworkparams") != std::string::npos)) {
        finding.add(ADAPTER_API, "PE import: adapter/route enumeration", example);
    }

    if ((d == "winhttp.dll" &&
         (f.find("winhttpgetieproxyconfigforcurrentuser") != std::string::npos ||
          f.find("winhttpgetproxyforurl") != std::string::npos)) ||
        (d == "wininet.dll" && f.find("internetqueryoption") != std::string::npos)) {
        finding.add(PROXY_API, "PE import: proxy API", example);
    }
}

static void ScanPeImports(const std::vector<uint8_t>& data, FileFinding& finding) {
    IMAGE_DOS_HEADER dos{};
    if (!ReadStruct(data, 0, dos) || dos.e_magic != IMAGE_DOS_SIGNATURE) return;
    if (dos.e_lfanew <= 0 || static_cast<size_t>(dos.e_lfanew) > data.size()) return;

    size_t ntOff = static_cast<size_t>(dos.e_lfanew);
    DWORD sig = 0;
    if (!ReadStruct(data, ntOff, sig) || sig != IMAGE_NT_SIGNATURE) return;

    IMAGE_FILE_HEADER fh{};
    if (!ReadStruct(data, ntOff + sizeof(DWORD), fh)) return;

    size_t optOff = ntOff + sizeof(DWORD) + sizeof(IMAGE_FILE_HEADER);
    WORD magic = 0;
    if (!ReadStruct(data, optOff, magic)) return;

    DWORD importRva = 0;
    if (magic == IMAGE_NT_OPTIONAL_HDR64_MAGIC) {
        IMAGE_OPTIONAL_HEADER64 opt{};
        if (!ReadStruct(data, optOff, opt)) return;
        importRva = opt.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress;
    } else if (magic == IMAGE_NT_OPTIONAL_HDR32_MAGIC) {
        IMAGE_OPTIONAL_HEADER32 opt{};
        if (!ReadStruct(data, optOff, opt)) return;
        importRva = opt.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress;
    } else {
        return;
    }

    if (!importRva) return;

    std::vector<IMAGE_SECTION_HEADER> sections;
    size_t secOff = optOff + fh.SizeOfOptionalHeader;
    for (WORD i = 0; i < fh.NumberOfSections; ++i) {
        IMAGE_SECTION_HEADER sec{};
        if (!ReadStruct(data, secOff + i * sizeof(IMAGE_SECTION_HEADER), sec)) return;
        sections.push_back(sec);
    }

    auto importOff = RvaToOffset(importRva, sections);
    if (!importOff) return;

    for (size_t descOff = *importOff; descOff + sizeof(IMAGE_IMPORT_DESCRIPTOR) <= data.size();
         descOff += sizeof(IMAGE_IMPORT_DESCRIPTOR)) {
        IMAGE_IMPORT_DESCRIPTOR desc{};
        if (!ReadStruct(data, descOff, desc)) return;
        if (!desc.Name && !desc.FirstThunk && !desc.OriginalFirstThunk) break;

        auto nameOff = RvaToOffset(desc.Name, sections);
        if (!nameOff) continue;
        std::string dll = ReadCString(data, *nameOff);
        if (dll.empty()) continue;

        DWORD thunkRva = desc.OriginalFirstThunk ? desc.OriginalFirstThunk : desc.FirstThunk;
        auto thunkOff = RvaToOffset(thunkRva, sections);
        if (!thunkOff) continue;

        if (magic == IMAGE_NT_OPTIONAL_HDR64_MAGIC) {
            for (size_t off = *thunkOff; off + sizeof(IMAGE_THUNK_DATA64) <= data.size(); off += sizeof(IMAGE_THUNK_DATA64)) {
                IMAGE_THUNK_DATA64 thunk{};
                if (!ReadStruct(data, off, thunk)) break;
                if (!thunk.u1.AddressOfData) break;
                if (thunk.u1.Ordinal & IMAGE_ORDINAL_FLAG64) continue;
                auto ibnOff = RvaToOffset(static_cast<DWORD>(thunk.u1.AddressOfData), sections);
                if (!ibnOff) continue;
                std::string fn = ReadCString(data, *ibnOff + sizeof(WORD));
                if (!fn.empty()) AddImportFinding(dll, fn, finding);
            }
        } else {
            for (size_t off = *thunkOff; off + sizeof(IMAGE_THUNK_DATA32) <= data.size(); off += sizeof(IMAGE_THUNK_DATA32)) {
                IMAGE_THUNK_DATA32 thunk{};
                if (!ReadStruct(data, off, thunk)) break;
                if (!thunk.u1.AddressOfData) break;
                if (thunk.u1.Ordinal & IMAGE_ORDINAL_FLAG32) continue;
                auto ibnOff = RvaToOffset(thunk.u1.AddressOfData, sections);
                if (!ibnOff) continue;
                std::string fn = ReadCString(data, *ibnOff + sizeof(WORD));
                if (!fn.empty()) AddImportFinding(dll, fn, finding);
            }
        }
    }
}

static bool ShouldScanFile(const fs::path& p) {
    std::wstring ext = ToLowerW(p.extension().wstring());
    static const std::unordered_set<std::wstring> exts = {
        L".exe", L".dll", L".ocx", L".cpl", L".node", L".sys",
        L".js", L".json", L".asar", L".pak", L".dat", L".bin",
        L".config", L".xml", L".txt"
    };
    return exts.count(ext) != 0;
}

static bool IsPeLike(const fs::path& p) {
    std::wstring ext = ToLowerW(p.extension().wstring());
    return ext == L".exe" || ext == L".dll" || ext == L".ocx" ||
           ext == L".cpl" || ext == L".node" || ext == L".sys";
}

static bool IsExe(const fs::path& p) {
    return ToLowerW(p.extension().wstring()) == L".exe";
}

static void AddExeCandidate(std::vector<fs::path>& out, const fs::path& exe) {
    if (!IsExe(exe)) return;
    std::error_code ec;
    fs::path canonical = fs::weakly_canonical(exe, ec);
    if (ec) canonical = exe;
    std::wstring key = ToLowerW(canonical.wstring());
    for (const auto& existing : out) {
        if (ToLowerW(existing.wstring()) == key) return;
    }
    out.push_back(canonical);
}

static std::optional<std::vector<uint8_t>> ReadFileBytes(const fs::path& p, uint64_t maxBytes) {
    std::error_code ec;
    uint64_t size = fs::file_size(p, ec);
    if (ec || size == 0 || size > maxBytes) return std::nullopt;

    std::ifstream f(p, std::ios::binary);
    if (!f) return std::nullopt;
    std::vector<uint8_t> data(static_cast<size_t>(size));
    f.read(reinterpret_cast<char*>(data.data()), static_cast<std::streamsize>(data.size()));
    if (!f && !f.eof()) return std::nullopt;
    return data;
}

static void ScanStrings(const std::vector<uint8_t>& data, FileFinding& finding) {
    std::string current;
    current.reserve(256);

    auto flushAscii = [&]() {
        if (current.size() >= 4) MatchTextIndicators(current, finding);
        current.clear();
    };

    for (uint8_t b : data) {
        if (b >= 0x20 && b <= 0x7e) {
            current.push_back(static_cast<char>(b));
            if (current.size() > 4096) flushAscii();
        } else {
            flushAscii();
        }
    }
    flushAscii();

    std::string utf16;
    utf16.reserve(256);
    auto flushUtf16 = [&]() {
        if (utf16.size() >= 4) MatchTextIndicators(utf16, finding);
        utf16.clear();
    };

    for (size_t i = 0; i + 1 < data.size(); i += 2) {
        uint8_t lo = data[i];
        uint8_t hi = data[i + 1];
        if (hi == 0 && lo >= 0x20 && lo <= 0x7e) {
            utf16.push_back(static_cast<char>(lo));
            if (utf16.size() > 4096) flushUtf16();
        } else {
            flushUtf16();
        }
    }
    flushUtf16();
}

static std::optional<FileFinding> ScanOneFile(const fs::path& p, const ScanOptions& opts) {
    auto bytes = ReadFileBytes(p, opts.maxFileBytes);
    if (!bytes) return std::nullopt;

    FileFinding finding;
    finding.file = p;

    if (IsPeLike(p)) ScanPeImports(*bytes, finding);
    ScanStrings(*bytes, finding);

    if (finding.flags == 0) return std::nullopt;
    return finding;
}

static std::vector<fs::path> EnumerateFilesUnder(const fs::path& root, const ScanOptions& opts, size_t& scannedCount) {
    std::vector<fs::path> files;
    std::error_code ec;
    if (ExistsFile(root)) {
        if (ShouldScanFile(root)) files.push_back(root);
        return files;
    }

    fs::recursive_directory_iterator it(
        root,
        fs::directory_options::skip_permission_denied,
        ec
    );
    fs::recursive_directory_iterator end;
    while (!ec && it != end) {
        const auto& entry = *it;
        if (opts.maxDepth >= 0 && it.depth() >= opts.maxDepth && entry.is_directory(ec) && !ec) {
            it.disable_recursion_pending();
        }
        ec.clear();
        if (entry.is_regular_file(ec) && !ec && ShouldScanFile(entry.path())) {
            files.push_back(entry.path());
            if (files.size() >= opts.maxFilesPerRoot) break;
        }
        it.increment(ec);
    }
    scannedCount = files.size();
    return files;
}

static AppFinding ScanRootForFindings(const ScanRoot& root, const ScanOptions& opts) {
    AppFinding app;
    app.root = root;

    size_t fileCount = 0;
    auto files = EnumerateFilesUnder(root.root, opts, fileCount);
    app.scannedFiles = fileCount;

    for (const auto& f : files) {
        if (IsExe(f)) AddExeCandidate(app.executableCandidates, f);

        auto ff = ScanOneFile(f, opts);
        if (!ff) continue;
        uint32_t flags = ff->flags;
        int fileScore = ScoreFlags(flags);
        if (fileScore < 10) continue;

        if (IsExe(f)) AddExeCandidate(app.executableCandidates, f);

        app.flags |= flags;
        if (fileScore >= opts.minScore || HasFlag(flags, RAS_API) || HasFlag(flags, RASPHONE)) {
            app.files.push_back(std::move(*ff));
        }
    }

    app.score = ScoreFlags(app.flags);
    if (!app.files.empty()) {
        app.score += static_cast<int>(std::min<size_t>(20, app.files.size() * 2));
    }
    return app;
}

static void PrintUsage() {
    std::wcout <<
        L"Usage: vpnscan.exe [--full] [--running-only] [--path DIR_OR_FILE]\n"
                   L"                   [--paths-only] [--min-score N]\n"
                   L"                   [--max-file-mb N] [--max-files-per-root N]\n"
                   L"                   [--max-depth N] [--json]\n\n"
        L"Default mode scans installed-app roots and currently running process dirs.\n"
        L"--running-only scans only currently running process dirs.\n"
        L"--full adds Program Files, Program Files (x86), LocalAppData, LocalAppData\\Programs.\n"
        L"--exe-only prints a concise list of risky executable candidates.\n";
}

static int ToIntArg(const wchar_t* value, int fallback) {
    if (!value) return fallback;
    wchar_t* end = nullptr;
    long parsed = std::wcstol(value, &end, 10);
    if (end == value) return fallback;
    if (parsed < 0) return fallback;
    if (parsed > 0x7fffffffL) return 0x7fffffff;
    return static_cast<int>(parsed);
}

static ScanOptions ParseArgs(int argc, wchar_t** argv) {
    ScanOptions opts;
    for (int i = 1; i < argc; ++i) {
        std::wstring a = argv[i];
        if (a == L"--help" || a == L"-h") {
            PrintUsage();
            ExitProcess(0);
        } else if (a == L"--full") {
            opts.full = true;
        } else if (a == L"--exe-only") {
            opts.exeOnly = true;
        } else if (a == L"--json") {
            opts.json = true;
        } else if (a == L"--paths-only") {
            opts.pathsOnly = true;
        } else if (a == L"--running-only") {
            opts.runningOnly = true;
        } else if (a == L"--path" && i + 1 < argc) {
            opts.customPaths.push_back(fs::path(argv[++i]));
        } else if (a == L"--min-score" && i + 1 < argc) {
            opts.minScore = std::max(0, ToIntArg(argv[++i], opts.minScore));
        } else if (a == L"--max-file-mb" && i + 1 < argc) {
            opts.maxFileBytes = static_cast<uint64_t>(std::max(1, ToIntArg(argv[++i], 150))) * 1024ull * 1024ull;
        } else if (a == L"--max-files-per-root" && i + 1 < argc) {
            opts.maxFilesPerRoot = static_cast<size_t>(std::max(1, ToIntArg(argv[++i], static_cast<int>(opts.maxFilesPerRoot))));
        } else if (a == L"--max-depth" && i + 1 < argc) {
            opts.maxDepth = ToIntArg(argv[++i], opts.maxDepth);
        } else {
            std::wcout << L"Unknown or incomplete argument: " << a << L"\n";
            PrintUsage();
            ExitProcess(2);
        }
    }
    return opts;
}

static void PrintFinding(const AppFinding& app) {
    std::wcout << L"\n================================================================================\n";
    std::wcout << L"App/root: " << app.root.name << L"\n";
    std::wcout << L"Path:     " << app.root.root.wstring() << L"\n";
    std::wcout << L"Source:   " << app.root.source << L"\n";
    std::wcout << L"Score:    " << app.score << L" (" << LabelForScore(app.score) << L")\n";
    std::wcout << L"Signals:  " << FlagsToText(app.flags) << L"\n";
    std::wcout << L"Files:    " << app.scannedFiles << L" scanned, " << app.files.size() << L" suspicious examples kept\n";

    if (!app.executableCandidates.empty()) {
        std::wcout << L"Risky executable candidates:\n";
        size_t exeShown = 0;
        for (const auto& exe : app.executableCandidates) {
            if (exeShown++ >= 12) {
                std::wcout << L"  ... more exe candidates omitted\n";
                break;
            }
            std::wcout << L"  " << exe.wstring() << L"\n";
        }
    } else {
        std::wcout << L"Risky executable candidates: none found in this root\n";
    }

    size_t shown = 0;
    for (const auto& f : app.files) {
        if (shown++ >= 8) {
            std::wcout << L"  ... more files omitted\n";
            break;
        }
        std::wcout << L"\n  File: " << f.file.wstring() << L"\n";
        std::wcout << L"  File score: " << ScoreFlags(f.flags) << L"\n";
        std::wcout << L"  File signals: " << FlagsToText(f.flags) << L"\n";

        size_t labelsShown = 0;
        for (const auto& [label, examples] : f.examples) {
            if (labelsShown++ >= 8) {
                std::wcout << L"    ... more labels omitted\n";
                break;
            }
            std::wcout << L"    - " << WidenAscii(label) << L"\n";
            for (const auto& ex : examples) {
                std::wcout << L"      example: " << WidenAscii(ex) << L"\n";
            }
        }
    }
}

static void PrintExeOnlyFinding(const AppFinding& app) {
    if (app.executableCandidates.empty()) {
        std::wcout << app.score << L"\t" << LabelForScore(app.score)
                   << L"\t" << app.root.root.wstring()
                   << L"\t(no exe found)"
                   << L"\t" << FlagsToText(app.flags) << L"\n";
        return;
    }

    for (const auto& exe : app.executableCandidates) {
        std::wcout << app.score << L"\t" << LabelForScore(app.score)
                   << L"\t" << app.root.root.wstring()
                   << L"\t" << exe.wstring()
                   << L"\t" << FlagsToText(app.flags) << L"\n";
    }
}

static std::string Utf8FromWide(const std::wstring& value) {
    if (value.empty()) return "";
    int needed = WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, nullptr, 0, nullptr, nullptr);
    if (needed <= 1) return "";
    std::string out(static_cast<size_t>(needed), '\0');
    WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, out.data(), needed, nullptr, nullptr);
    if (!out.empty() && out.back() == '\0') out.pop_back();
    return out;
}

static std::string Utf8FromPath(const fs::path& path) {
    return Utf8FromWide(path.wstring());
}

static void WriteJsonString(std::ostream& out, const std::string& value) {
    out << '"';
    for (unsigned char c : value) {
        switch (c) {
            case '"': out << "\\\""; break;
            case '\\': out << "\\\\"; break;
            case '\b': out << "\\b"; break;
            case '\f': out << "\\f"; break;
            case '\n': out << "\\n"; break;
            case '\r': out << "\\r"; break;
            case '\t': out << "\\t"; break;
            default:
                if (c < 0x20) {
                    out << "\\u" << std::hex << std::setw(4) << std::setfill('0')
                        << static_cast<int>(c) << std::dec << std::setfill(' ');
                } else {
                    out << static_cast<char>(c);
                }
        }
    }
    out << '"';
}

static std::vector<std::string> FlagNames(uint32_t flags) {
    std::vector<std::string> parts;
    if (HasFlag(flags, RAS_API)) parts.push_back("RAS API");
    if (HasFlag(flags, ADAPTER_API)) parts.push_back("adapter API");
    if (HasFlag(flags, PROXY_API)) parts.push_back("proxy API");
    if (HasFlag(flags, PROXY_CONFIG)) parts.push_back("proxy config");
    if (HasFlag(flags, RASPHONE)) parts.push_back("rasphone.pbk");
    if (HasFlag(flags, VPN_CLIENT)) parts.push_back("VPN client/adapter strings");
    if (HasFlag(flags, VPN_TELEMETRY)) parts.push_back("VPN telemetry fields");
    if (HasFlag(flags, TOR_SIGNAL)) parts.push_back("Tor strings");
    if (HasFlag(flags, WMI_ADAPTER)) parts.push_back("WMI adapter query");
    if (HasFlag(flags, GENERIC_VPN)) parts.push_back("generic vpn");
    return parts;
}

static void WriteJsonStringArray(std::ostream& out, const std::vector<std::string>& values) {
    out << '[';
    for (size_t i = 0; i < values.size(); ++i) {
        if (i) out << ',';
        WriteJsonString(out, values[i]);
    }
    out << ']';
}

static void PrintJsonFindings(const std::vector<AppFinding>& findings) {
    std::cout << "{\"findings\":[";
    for (size_t i = 0; i < findings.size(); ++i) {
        const auto& app = findings[i];
        if (i) std::cout << ',';
        std::cout << '{';
        std::cout << "\"score\":" << app.score << ',';
        std::cout << "\"label\":";
        WriteJsonString(std::cout, Utf8FromWide(LabelForScore(app.score)));
        std::cout << ',';
        std::cout << "\"rootName\":";
        WriteJsonString(std::cout, Utf8FromWide(app.root.name));
        std::cout << ',';
        std::cout << "\"rootPath\":";
        WriteJsonString(std::cout, Utf8FromPath(app.root.root));
        std::cout << ',';
        std::cout << "\"source\":";
        WriteJsonString(std::cout, Utf8FromWide(app.root.source));
        std::cout << ',';
        std::cout << "\"scannedFiles\":" << app.scannedFiles << ',';
        std::cout << "\"signals\":";
        WriteJsonStringArray(std::cout, FlagNames(app.flags));
        std::cout << ',';
        std::cout << "\"exeCandidates\":[";
        for (size_t exeIndex = 0; exeIndex < app.executableCandidates.size(); ++exeIndex) {
            if (exeIndex) std::cout << ',';
            WriteJsonString(std::cout, Utf8FromPath(app.executableCandidates[exeIndex]));
        }
        std::cout << "]}";
    }
    std::cout << "]}\n";
}

int wmain(int argc, wchar_t** argv) {
    SetConsoleOutputCP(CP_UTF8);

    ScanOptions opts = ParseArgs(argc, argv);
    auto roots = BuildScanRoots(opts);

    if (!opts.json) {
        std::wcout << L"Windows VPN-discovery scanner PoC\n";
        std::wcout << L"Roots to scan: " << roots.size() << L"\n";
        std::wcout << L"Min score: " << opts.minScore << L"\n";
        std::wcout << L"Max file size MB: " << (opts.maxFileBytes / 1024 / 1024) << L"\n";
        std::wcout << L"Exe-only output: " << (opts.exeOnly ? L"yes" : L"no") << L"\n";
        std::wcout << L"\nNote: static findings are indicators, not proof of exfiltration.\n";
    }

    std::vector<AppFinding> findings;
    size_t index = 0;
    for (const auto& root : roots) {
        ++index;
        if (!opts.json && (index % 25 == 0 || index == roots.size())) {
            std::wcout << L"Scanning root " << index << L"/" << roots.size() << L": "
                       << root.root.wstring() << L"\n";
        }

        AppFinding app = ScanRootForFindings(root, opts);
        if (app.score >= opts.minScore && app.flags != 0) {
            findings.push_back(std::move(app));
        }
    }

    std::sort(findings.begin(), findings.end(), [](const AppFinding& a, const AppFinding& b) {
        return a.score > b.score;
    });

    if (opts.json) {
        PrintJsonFindings(findings);
        return 0;
    }

    std::wcout << L"\nFindings >= min score: " << findings.size() << L"\n";
    if (opts.exeOnly) {
        std::wcout << L"\nscore\tlabel\troot_path\texe_path\tsignals\n";
        for (const auto& f : findings) {
            PrintExeOnlyFinding(f);
        }
    } else {
        for (const auto& f : findings) {
            PrintFinding(f);
        }
    }

    if (findings.empty()) {
        std::wcout << L"\nNo findings above threshold. Try --full or lower --min-score.\n";
    }

    return 0;
}
