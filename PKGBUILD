# Maintainer: rokybeast <sajid.shaik1186@gmail.com>
pkgname=wifilab
pkgver=1.0.0
pkgrel=1
pkgdesc="Automatic and Ready-to-use WiFi Pentesting Helpers"
arch=('any')
url="https://github.com/rokybeast/wifilab"
depends=('iw' 'iwd')
source=("${pkgname}-${pkgver}.tar.gz::${url}/archive/v${pkgver}.tar.gz")
sha256sums=('SKIP')  # Update with actual checksum later

package() {
    cd "${srcdir}/${pkgname}-${pkgver}"
    
    # Install every script
    for script in src/scripts/*.sh; do
        [ -f "$script" ] || continue
        scriptname=$(basename "$script" .sh)  # Remove .sh extension
        install -Dm755 "$script" "${pkgdir}/usr/bin/wifilab/${scriptname}"
    done
    # Install the wifilab script
    install -Dm755 src/wifilab.sh "${pkgdir}/usr/bin/wifilab"
    # Install README.md
    install -Dm644 README.md "${pkgdir}/usr/share/doc/${pkgname}/README.md"
}