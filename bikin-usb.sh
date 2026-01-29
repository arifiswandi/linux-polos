#!/bin/bash

# --- KONFIGURASI PATH ---
WORKDIR="$HOME/Mint_Modular_Project"
MOD_DIR="$WORKDIR/mint/modules"
ISO_NAME="$HOME/Mint_Modular_Final.iso"

# Pastikan tools pendukung terinstal
if ! command -v mksquashfs &> /dev/null; then
    echo "==> Menginstal tools pendukung..."
    sudo apt update && sudo apt install squashfs-tools xorriso grub-pc-bin mtools -y -qq
fi

# Buat folder kerja jika belum ada
mkdir -p "$MOD_DIR" "$WORKDIR/boot/grub" "$WORKDIR/DATA_USER"

case "$1" in
    "build-core")
        echo "==> 1. Membungkus Core Minimalis (GUI + Drivers)..."
        # Salin jantung sistem
        cp /vmlinuz "$WORKDIR/boot/vmlinuz"
        cp /initrd.img "$WORKDIR/boot/initrd.lz"
        
        # Pengecualian agar Core tidak bengkak
        cat > /tmp/exclude_core <<EOF
var/cache/*
var/lib/apt/lists/*
usr/share/doc/*
usr/share/man/*
home/*
tmp/*
dev/*
proc/*
sys/*
run/*
mnt/*
media/*
EOF
        sudo mksquashfs / "$MOD_DIR/01-core.squashfs" -ef /tmp/exclude_core -comp xz -b 1M
        
        # Buat Konfigurasi Booting
        cat > "$WORKDIR/boot/grub/grub.cfg" <<EOF
set timeout=5
set default=0
menuentry "Linux Mint Modular (OverlayFS)" {
    search --set=root --file /mint/modules/01-core.squashfs
    linux /boot/vmlinuz boot=casper persistence persistence-path=/mint/ persistence-label=casper-rw layerfs=overlay quiet splash ---
    initrd /boot/initrd.lz
}
EOF
        echo "✅ Modul Core (01) Berhasil Dibuat."
        ;;

    "build-apps")
        echo "==> 2. Membungkus Aplikasi Menjadi Modul Terpisah..."
        
        # Browser (Firefox)
        echo "[*] Membuat Modul Browser..."
        sudo mksquashfs /usr/lib/firefox /usr/bin/firefox /usr/share/firefox "$MOD_DIR/02-browser.squashfs" -comp xz

        # Office (LibreOffice)
        echo "[*] Membuat Modul Office..."
        sudo mksquashfs /usr/lib/libreoffice /usr/bin/libreoffice /usr/share/libreoffice "$MOD_DIR/03-office.squashfs" -comp xz

        # Media (VLC)
        echo "[*] Membuat Modul Media..."
        sudo mksquashfs /usr/bin/vlc /usr/lib/vlc /usr/share/vlc "$MOD_DIR/04-media.squashfs" -comp xz
        
        echo "✅ Modul Aplikasi (02, 03, 04) Berhasil Dibuat."
        ;;

    "make-module")
        # Untuk menambah aplikasi lain secara manual
        APP=$2
        if [ -z "$APP" ]; then echo "❌ Contoh: bikin-usb make-module gimp"; exit 1; fi
        NUM=$(ls "$MOD_DIR" | wc -l | xargs printf "%02d")
        sudo mksquashfs /usr/bin/$APP /usr/lib/$APP /usr/share/$APP "$MOD_DIR/${NUM}-${APP}.squashfs" -comp xz
        echo "✅ Modul $APP ditambahkan."
        ;;

    "remove-module")
        TARGET=$2
        if [ -z "$TARGET" ]; then echo "❌ Contoh: bikin-usb remove-module office"; exit 1; fi
        found=$(ls "$MOD_DIR" | grep "$TARGET")
        if [ -n "$found" ]; then
            rm -i "$MOD_DIR/$found"
            echo "✅ Modul $found dihapus."
        else
            echo "❌ Modul tidak ditemukan."
        fi
        ;;

    "list")
        echo "==> Daftar Modul di Folder Project:"
        ls -lh "$MOD_DIR"
        ;;

    "finish-iso")
        echo "==> 3. Membuat File ISO untuk Diuji..."
        # Buat dummy persistence agar folder /mint terbawa sempurna
        touch "$WORKDIR/mint/persistence.img" 
        grub-mkrescue -o "$ISO_NAME" "$WORKDIR"
        echo "✅ ISO SIAP: $ISO_NAME"
        ;;

    "connect")
        # Gunakan ini SETELAH boot dari USB
        USB_PATH=$(lsblk -pno MOUNTPOINT,LABEL | grep "LINUX_MINT" | awk '{print $1}')
        if [ -n "$USB_PATH" ]; then
            sudo mount --bind "$USB_PATH/DATA_USER" "$HOME/Documents"
            echo "✅ DATA_USER tersambung ke Documents."
        else
            echo "❌ USB tidak ditemukan. Pastikan label USB adalah LINUX_MINT."
        fi
        ;;

    *)
        echo "Penggunaan: bikin-usb [opsi]"
        echo "  build-core    : Buat sistem dasar (GUI)"
        echo "  build-apps    : Buat modul Browser, Office, Media"
        echo "  make-module   : Buat modul baru (contoh: bikin-usb make-module gimp)"
        echo "  remove-module : Hapus modul (contoh: bikin-usb remove-module office)"
        echo "  list          : Lihat semua modul yang ada"
        echo "  finish-iso    : Bungkus semua menjadi file ISO"
        echo "  connect       : Sambungkan data USB ke folder Documents"
        ;;
esac