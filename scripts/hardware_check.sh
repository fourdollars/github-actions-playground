#!/bin/bash

echo "========================================"
echo "    Linux Hardware Capability Report"
echo "========================================"
echo

# Check if the script is running as root
if [ "$(id -u)" -eq 0 ]; then
    IS_ROOT=true
    echo "  Running as root user."
else
    IS_ROOT=false
    echo "  Running as non-root user."
fi
echo

# ---

# Initialize summary variables
MOUNT_SUMMARY="N/A"
APT_SUMMARY="N/A"
MEM_SUMMARY="N/A"
DISK_SUMMARY="N/A"
CPU_SUMMARY="N/A"
GPU_SUMMARY="N/A"

# 1. Checking 'mount' Command Availability and Execution
echo "--- 1. Checking 'mount' Command Availability and Execution ---"
if command -v mount &> /dev/null; then
    echo "  ✅'mount' command is available."
    if [ "$IS_ROOT" = true ]; then
        mkdir -p /mnt/temp_mount_test &> /dev/null
        if mount --bind / /mnt/temp_mount_test &> /dev/null; then
            echo "  ✅'mount' command executed successfully (bind mount test)."
            umount /mnt/temp_mount_test &> /dev/null
            rmdir /mnt/temp_mount_test &> /dev/null
            MOUNT_SUMMARY="Available and Executable (as root)"
        else
            echo "  ❌ 'mount' command is available but failed basic execution (bind mount test)."
            echo "    (Error might indicate permissions or other system issues)"
            rmdir /mnt/temp_mount_test &> /dev/null
            MOUNT_SUMMARY="Available but Test Failed (as root)"
        fi
    else
        echo "  ✅'mount' command is available. (Root privileges are typically required for a meaningful 'mount' operation.)"
        echo "  --- Checking 'sudo mount' capability ---"
        if command -v sudo &> /dev/null; then
            if sudo -n mkdir -p /mnt/temp_mount_test &> /dev/null; then
                if sudo -n mount --bind / /mnt/temp_mount_test &> /dev/null; then
                    echo "  ✅User can execute 'sudo mount --bind / /mnt/temp_mount_test' successfully (without password)."
                    sudo -n umount /mnt/temp_mount_test &> /dev/null
                    sudo -n rmdir /mnt/temp_mount_test &> /dev/null
                    MOUNT_SUMMARY="Available; Sudo Mount Executable (without password)"
                else
                    echo "  ❌ 'sudo mount --bind / /mnt/temp_mount_test' failed without password (or test failed)."
                    echo "    (You may be prompted for a password, or 'mount' may not be allowed via sudoers file)"
                    sudo -n rmdir /mnt/temp_mount_test &> /dev/null
                    MOUNT_SUMMARY="Available; Sudo Mount Test Failed"
                fi
            else
                echo "  ❌ User cannot execute 'sudo mkdir' for temp mount point (or test failed)."
                MOUNT_SUMMARY="Available; Sudo mkdir Test Failed"
            fi
        else
            echo "  ❌ 'sudo' command is not available."
            MOUNT_SUMMARY="Available; Sudo Not Available"
        fi
    fi
else
    echo "  ❌ 'mount' command is not available."
    MOUNT_SUMMARY="Not Available"
fi
echo

# ---

# 2. Checking 'apt' Command Availability and Execution
echo "--- 2. Checking 'apt' Command Availability and Execution ---"
if command -v apt &> /dev/null; then
    echo "  ✅'apt' command is available. This system is likely Debian/Ubuntu based."
    echo "  Attempting 'apt-get install --reinstall --yes hello' as an execution test..."

    if [ "$IS_ROOT" = true ]; then
        if apt-get install --reinstall --yes hello &> /dev/null; then
            echo "  ✅'apt-get install --reinstall --yes hello' executed successfully (as root)."
            APT_SUMMARY="Available and Executable (as root)"
        else
            echo "  ❌ 'apt-get install --reinstall --yes hello' failed (as root). This might indicate repository, network issues, or 'hello' package not available."
            APT_SUMMARY="Available but Test Failed (as root)"
        fi
    else
        echo "  ⚠️This test requires root privileges. Attempting with 'sudo'."
        if command -v sudo &> /dev/null; then
            if sudo -n apt-get install --reinstall --yes hello &> /dev/null; then
                echo "  ✅User can execute 'sudo apt-get install --reinstall --yes hello' successfully (without password)."
                APT_SUMMARY="Available; Sudo Apt Executable (without password)"
            else
                echo "  ❌ User cannot execute 'sudo apt-get install --reinstall --yes hello' without password (or test failed)."
                echo "    (You may be prompted for a password, or 'apt-get install' may not be allowed via sudoers file)"
                APT_SUMMARY="Available; Sudo Apt Test Failed"
            fi
        else
            echo "  ❌ 'sudo' command is not available."
            APT_SUMMARY="Available; Sudo Not Available"
        fi
    fi
else
    echo "  ❌ 'apt' command is not available. This system might not be a Debian/Ubuntu based distribution."
    echo "    (You might need to use another package manager like 'yum' or 'dnf' etc.)"
    APT_SUMMARY="Not Available"
fi
echo

# ---

# 3. Memory Information
echo "--- 3. Memory Information ---"
MEM_INFO=$(free -h)
echo "$MEM_INFO"
echo
echo "  (Explanation: total = total memory, used = used memory, free = free memory, shared = shared memory, buff/cache = buffer/cache memory, available = actual available memory)"
# Extract total memory for summary
TOTAL_MEM=$(echo "$MEM_INFO" | awk 'NR==2{print $2}')
MEM_SUMMARY="Total: $TOTAL_MEM"
echo

# ---

# 4. Disk Space Information
echo "--- 4. Disk Space Information ---"
echo "  Filesystem Types:"
df -T | awk 'NR==1 || /^\// {print $2, $1}' | column -t
echo

echo "  Disk Usage (Size, Used, Avail, Use%):"
DISK_USAGE=$(df -h --output=size,used,avail,pcent,target)
echo "$DISK_USAGE"
echo
echo "  (Explanation: Size = total size, Used = used size, Avail = available size, Use% = usage percentage, Target = mount point)"
# Extract root partition usage for summary
ROOT_USAGE=$(echo "$DISK_USAGE" | grep -w '/' | awk '{print $4 " used (" $3 "/" $2 ")"}')
if [ -z "$ROOT_USAGE" ]; then # If root usage isn't found this way (e.g., in a container)
    ROOT_USAGE=$(echo "$DISK_USAGE" | awk 'NR>1 {sum_used+=$3; sum_size+=$2} END {if (sum_size>0) print sum_used " used / " sum_size; else print "N/A"}')
fi
DISK_SUMMARY="Root/Total Disk Usage: $ROOT_USAGE"
echo

# ---

# 5. CPU Information
echo "--- 5. CPU Information ---"
if command -v lscpu &> /dev/null; then
    CPU_INFO=$(lscpu)
    echo "$CPU_INFO"
    CPU_MODEL=$(echo "$CPU_INFO" | grep 'Model name:' | awk -F ': +' '{print $2}')
    CPU_CORES=$(echo "$CPU_INFO" | grep 'CPU(s):' | awk '{print $2}' | head -n 1) # Get overall CPU(s) count
    CPU_SUMMARY="Model: $CPU_MODEL, Cores/Threads: $CPU_CORES"
else
    echo "  ❌ 'lscpu' command is not available. Trying to get basic info from /proc/cpuinfo..."
    CPU_INFO=$(grep -E 'model name|cpu cores|processor' /proc/cpuinfo | head -n 10)
    echo "$CPU_INFO"
    echo "  (It's recommended to install 'util-linux' package for more detailed CPU information)"
    CPU_SUMMARY="Basic info from /proc/cpuinfo"
fi
echo

# ---

# 6. GPU Information
echo "--- 6. GPU Information ---"
echo "  Attempting to check GPU information..."
GPU_STATUS="Not Detected"

if ! command -v lspci &> /dev/null; then
    echo "  ❌ 'lspci' command is not available. Cannot list PCI devices."
    echo "    (It's recommended to install 'pciutils' package for more detailed GPU information)"
    GPU_STATUS="lspci Not Available"
else
    if lspci | grep -E 'VGA compatible controller|3D controller' &> /dev/null; then
        echo "  ✅Graphics card detected. Details:"
        lspci -k | grep -EA3 'VGA|3D|Display'

        if command -v nvidia-smi &> /dev/null; then
            echo
            echo "  --- NVIDIA GPU Information (via nvidia-smi) ---"
            nvidia-smi
            GPU_STATUS="NVIDIA GPU Detected (via nvidia-smi)"
        elif lsmod | grep -q nouveau; then
            echo
            echo "  ✅Nouveau driver detected (Open-source NVIDIA driver)."
            echo "    (Installing NVIDIA proprietary drivers can provide more info and performance)"
            GPU_STATUS="NVIDIA GPU Detected (Nouveau Driver)"
        elif command -v rocm-smi &> /dev/null; then
            echo
            echo "  --- AMD GPU Information (via rocm-smi) ---"
            rocm-smi
            GPU_STATUS="AMD GPU Detected (via rocm-smi)"
        elif lsmod | grep -q amdgpu; then
            echo
            echo "  ✅amdgpu driver detected."
            echo "    (To get detailed information, you might need to install ROCm related tools)"
            GPU_STATUS="AMD GPU Detected (amdgpu Driver)"
        else
            echo "  ※ Although a graphics card was detected, no specific GPU monitoring tools (like nvidia-smi or rocm-smi) were found."
            echo "    You might need to install vendor-provided drivers and tools for more detailed information."
            GPU_STATUS="Graphics Card Detected (No specific tool)"
        fi
    else
        echo "  ❌ No dedicated graphics card detected (VGA compatible controller or 3D controller)."
        echo "    This system might be using integrated graphics or has no graphics output."
        GPU_STATUS="No Dedicated GPU Detected"
    fi
fi
GPU_SUMMARY="$GPU_STATUS"
echo

echo "========================================"
echo "          End of Detailed Report"
echo "========================================"

# ---

### **SUMMARY REPORT**

echo "--- Summary Report ---"
echo "Role: $(if [ "$IS_ROOT" = true ]; then echo "Root"; else echo "Non-Root"; fi)"
echo "Mount Command: $MOUNT_SUMMARY"
echo "APT Command: $APT_SUMMARY"
echo "Memory: $MEM_SUMMARY"
echo "Disk Space: $DISK_SUMMARY"
echo "CPU: $CPU_SUMMARY"
echo "GPU: $GPU_SUMMARY"
echo "----------------------"
echo "========================================"
