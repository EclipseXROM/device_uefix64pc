#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORK_DIR="${DEVICE_DIR}/out/kernel"
SRC_DIR="${WORK_DIR}/src"
BUILD_DIR="${WORK_DIR}/build"
PREBUILT_KERNEL_DIR="${DEVICE_DIR}/prebuilts/kernel"
PREBUILT_MODULES_DIR="${DEVICE_DIR}/prebuilts/modules"
KERNEL_ARCHIVE="${KERNEL_ARCHIVE:-${SCRIPT_DIR}/linux-6.19.6.tar.xz}"
DEFCONFIG="${DEFCONFIG:-android-x86_64_defconfig}"
JOBS="${JOBS:-$(nproc)}"
STAMP_FILE="${WORK_DIR}/.kernel-archive.sha256"
NVIDIA_DIR="${SCRIPT_DIR}/nvidia"

if [[ ! -f "${KERNEL_ARCHIVE}" ]]; then
  echo "[ERROR] Kernel archive not found: ${KERNEL_ARCHIVE}" >&2
  exit 1
fi

mkdir -p "${WORK_DIR}" "${BUILD_DIR}" "${PREBUILT_KERNEL_DIR}" "${PREBUILT_MODULES_DIR}"

NEW_SUM="$(sha256sum "${KERNEL_ARCHIVE}" | awk '{print $1}')"
CURRENT_SUM=""
if [[ -f "${STAMP_FILE}" ]]; then
  CURRENT_SUM="$(cat "${STAMP_FILE}")"
fi

if [[ "${NEW_SUM}" != "${CURRENT_SUM}" || ! -d "${SRC_DIR}" ]]; then
  echo "[*] Extracting kernel archive ..."
  rm -rf "${SRC_DIR}"
  mkdir -p "${SRC_DIR}"
  tar -xJf "${KERNEL_ARCHIVE}" -C "${SRC_DIR}" --strip-components=1
  echo "${NEW_SUM}" > "${STAMP_FILE}"
fi

pushd "${SRC_DIR}" >/dev/null
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
