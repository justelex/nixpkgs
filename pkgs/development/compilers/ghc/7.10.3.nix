{ stdenv, fetchurl, fetchpatch, ghc, perl, gmp, ncurses, libiconv, binutils, coreutils
, libxml2, libxslt, docbook_xsl, docbook_xml_dtd_45, docbook_xml_dtd_42, hscolour
}:

let

  buildMK = ''
    libraries/integer-gmp_CONFIGURE_OPTS += --configure-option=--with-gmp-libraries="${gmp}/lib"
    libraries/integer-gmp_CONFIGURE_OPTS += --configure-option=--with-gmp-includes="${gmp}/include"
    libraries/terminfo_CONFIGURE_OPTS += --configure-option=--with-curses-includes="${ncurses}/include"
    libraries/terminfo_CONFIGURE_OPTS += --configure-option=--with-curses-libraries="${ncurses}/lib"
    ${stdenv.lib.optionalString stdenv.isDarwin ''
      libraries/base_CONFIGURE_OPTS += --configure-option=--with-iconv-includes="${libiconv}/include"
      libraries/base_CONFIGURE_OPTS += --configure-option=--with-iconv-libraries="${libiconv}/lib"
    ''}
  '';

  docFixes = fetchurl {
    url = "https://downloads.haskell.org/~ghc/7.10.3/ghc-7.10.3a.patch";
    sha256 = "1j45z4kcd3w1rzm4hapap2xc16bbh942qnzzdbdjcwqznsccznf0";
  };

in

stdenv.mkDerivation rec {
  version = "7.10.3";
  name = "ghc-${version}";

  src = fetchurl {
    url = "https://downloads.haskell.org/~ghc/${version}/${name}-src.tar.xz";
    sha256 = "1vsgmic8csczl62ciz51iv8nhrkm72lyhbz7p7id13y2w7fcx46g";
  };

  patches = [
    docFixes
  ];

  buildInputs = [ ghc perl libxml2 libxslt docbook_xsl docbook_xml_dtd_45 docbook_xml_dtd_42 hscolour ];

  enableParallelBuilding = true;

  preConfigure = ''
    echo >mk/build.mk "${buildMK}"
    sed -i -e 's|-isysroot /Developer/SDKs/MacOSX10.5.sdk||' configure
  '' + stdenv.lib.optionalString (!stdenv.isDarwin) ''
    export NIX_LDFLAGS="$NIX_LDFLAGS -rpath $out/lib/ghc-${version}"
  '' + stdenv.lib.optionalString stdenv.isDarwin ''
    export NIX_LDFLAGS+=" -no_dtrace_dof"
  '';

  configureFlags = [
    "--with-gcc=${stdenv.cc}/bin/cc"
    "--with-gmp-includes=${gmp}/include" "--with-gmp-libraries=${gmp}/lib"
  ];

  # required, because otherwise all symbols from HSffi.o are stripped, and
  # that in turn causes GHCi to abort
  stripDebugFlags = [ "-S" ] ++ stdenv.lib.optional (!stdenv.isDarwin) "--keep-file-symbols";

  postInstall = ''
    # Install the bash completion file.
    install -D -m 444 utils/completion/ghc.bash $out/share/bash-completion/completions/ghc

    # Patch scripts to include "readelf" and "cat" in $PATH.
    for i in "$out/bin/"*; do
      test ! -h $i || continue
      egrep --quiet '^#!' <(head -n 1 $i) || continue
      sed -i -e '2i export PATH="$PATH:${binutils}/bin:${coreutils}/bin"' $i
    done
  '';

  meta = {
    homepage = "http://haskell.org/ghc";
    description = "The Glasgow Haskell Compiler";
    maintainers = with stdenv.lib.maintainers; [ marcweber andres simons ];
    inherit (ghc.meta) license platforms;
  };

}
