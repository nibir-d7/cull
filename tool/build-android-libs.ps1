param(
  [string]$Ndk = $env:ANDROID_NDK_HOME,
  [string]$OutDir = "app_flutter\android\app\src\main\jniLibs"
)

$ErrorActionPreference = "Stop"

if (-not $Ndk) {
  $sdk = $env:ANDROID_HOME
  if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
  if (-not $sdk) { throw "set ANDROID_NDK_HOME, or ANDROID_HOME pointing at an SDK with an ndk/ directory" }
  $versions = Get-ChildItem (Join-Path $sdk "ndk") -Directory -ErrorAction SilentlyContinue |
    Sort-Object { [version]$_.Name } -Descending
  if (-not $versions) { throw "no NDK found under $sdk\ndk" }
  $Ndk = $versions[0].FullName
}

$hostTag = if ($IsWindows -or $env:OS -eq "Windows_NT") { "windows-x86_64" } else { "darwin-x86_64" }
$bin = Join-Path $Ndk "toolchains\llvm\prebuilt\$hostTag\bin"
if (-not (Test-Path $bin)) { $bin = Join-Path $Ndk "toolchains/llvm/prebuilt/$hostTag/bin" }
if (-not (Test-Path $bin)) { throw "cannot locate the NDK clang wrappers under $Ndk" }

$targets = @(
  @{ abi = "arm64-v8a";   arch = "arm64"; cc = "aarch64-linux-android24-clang.cmd" },
  @{ abi = "armeabi-v7a"; arch = "arm";   cc = "armv7a-linux-androideabi24-clang.cmd" },
  @{ abi = "x86_64";      arch = "amd64"; cc = "x86_64-linux-android24-clang.cmd" }
)

foreach ($t in $targets) {
  $out = Join-Path $OutDir $t.abi
  New-Item -ItemType Directory -Force -Path $out | Out-Null
  $so = Join-Path $out "libcull.so"

  $env:CC = Join-Path $bin $t.cc
  $env:CGO_ENABLED = "1"
  $env:GOOS = "android"
  $env:GOARCH = $t.arch

  Write-Host "building $($t.abi) ($($t.arch))"
  go build -buildmode=c-shared -tags android -o $so ./ffi
  if ($LASTEXITCODE -ne 0) { throw "build failed for $($t.abi)" }
  Write-Host ("  {0}  {1:N1} MB" -f $t.abi, ((Get-Item $so).Length / 1MB))
}

Write-Host "wrote $OutDir"
