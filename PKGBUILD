# Maintainer: clpi <clp@clp.is>
pkgname=wx-bin
pkgver=0.1.0
pkgrel=1
pkgdesc="WebAssembly runtime written in Zig with basic WASI support"
arch=('x86_64')
url="https://github.com/clpi/wx"
license=('MIT')
provides=('wx')
conflicts=('wx')
source=("https://github.com/clpi/wx/releases/download/v${pkgver}/wx-linux-x86_64")
sha256sums=('SKIP')  # Will be updated by release workflow

package() {
  install -Dm755 "${srcdir}/wx-linux-x86_64" "${pkgdir}/usr/bin/wx"
}

# vim:set ts=2 sw=2 et:
