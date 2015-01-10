using BinDeps

@BinDeps.setup

libOS = library_dependency("libOS")
version = "2.8.4"

provides(Sources, URI("http://www.coin-or.org/download/source/OS/OS-$version.tgz"),
    [libOS], os = :Unix)

@osx_only begin
    using Homebrew
    #provides(Homebrew.HB, "OptimizationServices", [libOS], os = :Darwin)
end

@windows_only begin
    using WinRPM
    #provides(WinRPM.RPM, "OptimizationServices", [libOS], os = :Windows)
end

prefix = joinpath(BinDeps.depsdir(libOS), "usr")
patchdir = BinDeps.depsdir(libOS)
srcdir = joinpath(BinDeps.depsdir(libOS), "src", "OS-$version")

@linux_only begin
    cbcdir = Pkg.dir("Cbc","deps","usr")
    ipoptdir = Pkg.dir("Ipopt","deps","usr")
end
@osx_only begin
    cbcdir = Homebrew.prefix()
    ipoptdir = Homebrew.prefix()
end
ENV2 = copy(ENV)
ENV2["PKG_CONFIG_PATH"] = joinpath(cbcdir,"lib","pkgconfig") *
    ":" * joinpath(ipoptdir,"lib","pkgconfig")

provides(SimpleBuild,
    (@build_steps begin
        GetSources(libOS)
        @build_steps begin
            ChangeDirectory(srcdir)
            `cat $patchdir/OS-clang.patch` |> `patch -p1`
            setenv(`./configure --prefix=$prefix --enable-dependency-linking
                --with-coinutils-lib="-L$(joinpath(cbcdir,"lib")) -lCoinUtils"
                --with-coinutils-incdir=$(joinpath(cbcdir,"include","coin"))
                --with-osi-lib="-L$(joinpath(cbcdir,"lib")) -lOsi"
                --with-osi-incdir=$(joinpath(cbcdir,"include","coin"))
                --with-clp-lib="-L$(joinpath(cbcdir,"lib")) -lClp"
                --with-clp-incdir=$(joinpath(cbcdir,"include","coin"))
                --with-cgl-lib="-L$(joinpath(cbcdir,"lib")) -lCgl"
                --with-cgl-incdir=$(joinpath(cbcdir,"include","coin"))
                --with-cbc-lib="-L$(joinpath(cbcdir,"lib")) -lCbc"
                --with-cbc-incdir=$(joinpath(cbcdir,"include","coin"))
                --with-blas="-L$(joinpath(ipoptdir,"lib")) -lcoinblas"
                --with-lapack="-L$(joinpath(ipoptdir,"lib")) -lcoinlapack"
                --with-mumps-lib="-L$(joinpath(ipoptdir,"lib")) -lcoinmumps"
                --with-ipopt-lib="-L$(joinpath(ipoptdir,"lib")) -lipopt"`, ENV2)
            `make install`
        end
    end), [libOS], os = :Unix)

@BinDeps.install [:libOS => :libOS]
