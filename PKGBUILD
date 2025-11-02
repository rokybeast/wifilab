# Maintainer: rokybeast <sajid.shaik1186@gmail.com>
pkgname=wifilab
pkgver=1.0.0
pkgrel=1
pkgdesc="Automatic and Ready-to-use WiFi Pentesting Helpers"
arch=('any')
url="https://github.com/rokybeast/wifilab"
depends=('iw' 'iwd')
source=("${pkgname}-${pkgver}.tar.gz::${url}/archive/v${pkgver}.tar.gz")
sha256sums=('a6c6701f07d0a954a940ec117888bc08cd9d1c4a984ec0d011c9d305ae657317') # updated

package() {
    cd "${srcdir}/${pkgname}-${pkgver}"
    
    # Install every script into /usr/bin (not a nested /usr/bin/wifilab/ dir)
    for script in src/scripts/*.sh; do
        [ -f "$script" ] || continue
        scriptname=$(basename "$script" .sh)  # Remove .sh extension
        install -Dm755 "$script" "${pkgdir}/usr/bin/${scriptname}"
    done
    # Install the wifilab script
    install -Dm755 src/wifilab.sh "${pkgdir}/usr/bin/wifilab"
    # Install README.md
    install -Dm644 README.md "${pkgdir}/usr/share/doc/${pkgname}/README.md"
}