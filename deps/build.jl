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

ENV2 = copy(ENV)
ENV2["PKG_CONFIG_PATH"] = Pkg.dir("Cbc","deps","usr","lib","pkgconfig") *
    ":" * Pkg.dir("Ipopt","deps","usr","lib","pkgconfig")
provides(SimpleBuild,
    (@build_steps begin
        GetSources(libOS)
        @build_steps begin
            ChangeDirectory(srcdir)
            setenv(`./configure --prefix=$prefix --enable-dependency-linking
                --with-coinutils-lib="-L$(Pkg.dir("Cbc","deps","usr","lib")) -lCoinUtils"
                --with-coinutils-incdir=$(Pkg.dir("Cbc","deps","usr","include","coin"))
                --with-osi-lib="-L$(Pkg.dir("Cbc","deps","usr","lib")) -lOsi"
                --with-osi-incdir=$(Pkg.dir("Cbc","deps","usr","include","coin"))
                --with-clp-lib="-L$(Pkg.dir("Cbc","deps","usr","lib")) -lClp"
                --with-clp-incdir=$(Pkg.dir("Cbc","deps","usr","include","coin"))
                --with-cgl-lib="-L$(Pkg.dir("Cbc","deps","usr","lib")) -lCgl"
                --with-cgl-incdir=$(Pkg.dir("Cbc","deps","usr","include","coin"))
                --with-cbc-lib="-L$(Pkg.dir("Cbc","deps","usr","lib")) -lCbc"
                --with-cbc-incdir=$(Pkg.dir("Cbc","deps","usr","include","coin"))
                --with-blas="-L$(Pkg.dir("Ipopt","deps","usr","lib")) -lcoinblas"
                --with-lapack="-L$(Pkg.dir("Ipopt","deps","usr","lib")) -lcoinlapack"
                --with-mumps-lib="-L$(Pkg.dir("Ipopt","deps","usr","lib")) -lcoinmumps"
                --with-ipopt-lib="-L$(Pkg.dir("Ipopt","deps","usr","lib")) -lipopt"`, ENV2)
            `make install`
        end
    end), [libOS], os = :Unix)

@BinDeps.install [:libOS => :libOS]
