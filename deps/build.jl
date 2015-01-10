using BinDeps

@BinDeps.setup

libOS = library_dependency("libOS")
version = "2.8.4"

provides(Sources, URI("http://www.coin-or.org/download/source/OS/OS-$version.tgz"),
    [libOS], os = :Unix)

@windows_only begin
    using WinRPM
    #provides(WinRPM.RPM, "OptimizationServices", [libOS], os = :Windows)
    # TODO until WinRPM is all ready, download win32 binary of CoinAll?
    # May be impossible to satisfy BinDeps library_dependency for win64 Julia in that case
    cbcdir = joinpath(WinRPM.installdir, "usr", Sys.MACHINE, "sys-root", "mingw", "bin")
    ipoptdir = cbcdir
end

@osx_only begin
    using Homebrew
    #provides(Homebrew.HB, "OptimizationServices", [libOS], os = :Darwin)
    cbcdir = Homebrew.prefix()
    ipoptdir = cbcdir
    # fixup ipopt.pc
    rm(joinpath(ipoptdir, "lib", "pkgconfig", "ipopt.pc"))
    download("https://gist.githubusercontent.com/tkelman/ef929966684db2466592/raw/088df134829e025fb9fa2bbb88d509ee9499a81b/ipopt.pc",
        joinpath(ipoptdir, "lib", "pkgconfig", "ipopt.pc"))
end

@linux_only begin
    cbcdir = Pkg.dir("Cbc", "deps", "usr")
    ipoptdir = Pkg.dir("Ipopt", "deps", "usr")
end

prefix = joinpath(BinDeps.depsdir(libOS), "usr")
patchdir = BinDeps.depsdir(libOS)
srcdir = joinpath(BinDeps.depsdir(libOS), "src", "OS-$version")

ENV2 = copy(ENV)
@unix_only ENV2["PKG_CONFIG_PATH"] = joinpath(cbcdir, "lib", "pkgconfig") *
    ":" * joinpath(ipoptdir, "lib", "pkgconfig")

provides(SimpleBuild,
    (@build_steps begin
        GetSources(libOS)
        @build_steps begin
            ChangeDirectory(srcdir)
            `cat $patchdir/OS-clang.patch` |> `patch -p1`
            setenv(`./configure --prefix=$prefix --enable-dependency-linking
                coin_skip_warn_cflags=yes coin_skip_warn_cxxflags=yes coin_skip_warn_fflags=yes
                --with-coinutils-lib="-L$(joinpath(cbcdir,"lib")) -lCoinUtils"
                --with-coinutils-incdir=$(joinpath(cbcdir,"include","coin"))
                --with-osi-lib="-L$(joinpath(cbcdir,"lib")) -lOsi -lCoinUtils"
                --with-osi-incdir=$(joinpath(cbcdir,"include","coin"))
                --with-clp-lib="-L$(joinpath(cbcdir,"lib")) -lClp -lOsiClp"
                --with-clp-incdir=$(joinpath(cbcdir,"include","coin"))
                --with-cgl-lib="-L$(joinpath(cbcdir,"lib")) -lCgl"
                --with-cgl-incdir=$(joinpath(cbcdir,"include","coin"))
                --with-cbc-lib="-L$(joinpath(cbcdir,"lib")) -lCbc"
                --with-cbc-incdir=$(joinpath(cbcdir,"include","coin"))
                --with-blas="-L$(joinpath(ipoptdir,"lib")) -lcoinblas"
                --with-lapack="-L$(joinpath(ipoptdir,"lib")) -lcoinlapack"
                --with-mumps-lib="-L$(joinpath(ipoptdir,"lib")) -lcoinmumps"
                --with-ipopt-lib="-L$(joinpath(ipoptdir,"lib")) -lipopt"`, ENV2)
            `make`
            `make -j1 install`
            `make test`
        end
    end), [libOS], os = :Unix)

@BinDeps.install [:libOS => :libOS]
