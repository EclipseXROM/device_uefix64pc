#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORK_DIR="${DEVICE_DIR}/out/kernel"
SRC_TREE="${KERNEL_TREE:-${SCRIPT_DIR}/linux-6.19.6}"
BUILD_DIR="${WORK_DIR}/build"
PREBUILT_KERNEL_DIR="${DEVICE_DIR}/prebuilts/kernel"
PREBUILT_MODULES_DIR="${DEVICE_DIR}/prebuilts/modules"
DEFCONFIG="${DEFCONFIG:-android-x86_64_defconfig}"
JOBS="${JOBS:-$(nproc)}"
NVIDIA_DIR="${SCRIPT_DIR}/nvidia"

if [[ ! -d "${SRC_TREE}" ]]; then
  echo "[ERROR] Kernel source tree not found: ${SRC_TREE}" >&2
  exit 1
fi

mkdir -p "${WORK_DIR}" "${BUILD_DIR}" "${PREBUILT_KERNEL_DIR}" "${PREBUILT_MODULES_DIR}"

pushd "${SRC_TREE}" >/dev/null
make O="${BUILD_DIR}" "${DEFCONFIG}"
make O="${BUILD_DIR}" -j"${JOBS}"
popd >/dev/null

BZIMAGE_PATH="${BUILD_DIR}/arch/x86/boot/bzImage"
if [[ ! -f "${BZIMAGE_PATH}" ]]; then
  echo "[ERROR] Built kernel image not found: ${BZIMAGE_PATH}" >&2
  exit 1
fi

cp "${BZIMAGE_PATH}" "${PREBUILT_KERNEL_DIR}/bzImage"

rm -f "${PREBUILT_MODULES_DIR}"/*.ko
dst_modules=()
while IFS= read -r -d '' module; do
  cp "${module}" "${PREBUILT_MODULES_DIR}/"
  dst_modules+=("${module}")
done < <(find "${BUILD_DIR}" -type f -name '*.ko' -print0)

echo "[*] Copied ${#dst_modules[@]} built-in modules"

if [[ -d "${NVIDIA_DIR}" ]]; then
  mapfile -t nvidia_mods < <(find "${NVIDIA_DIR}" -maxdepth 1 -type f -name '*.ko')
  if [[ ${#nvidia_mods[@]} -gt 0 ]]; then
    for mod in "${nvidia_mods[@]}"; do
      cp "${mod}" "${PREBUILT_MODULES_DIR}/"
    done
    echo "[*] Added ${#nvidia_mods[@]} NVIDIA module(s)"
  fi
fi

echo "[*] Kernel prebuilts refreshed in ${PREBUILT_KERNEL_DIR} and ${PREBUILT_MODULES_DIR}"
