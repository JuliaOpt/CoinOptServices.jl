using BinDeps, Compat

@BinDeps.setup

libOS = library_dependency("libOS", aliases=["libOS-6"])
version = "2.9.2"

provides(Sources, URI("http://www.coin-or.org/download/source/OS/OS-$version.tgz"),
    [libOS], os = :Unix)

@windows_only begin
    using WinRPM
    push!(WinRPM.sources, "http://download.opensuse.org/repositories/home:/kelman:/mingw-coinor/openSUSE_13.1")
    WinRPM.update()
    provides(WinRPM.RPM, "OptimizationServices", [libOS], os = :Windows)
    cbclibdir = joinpath(WinRPM.installdir, "usr", Sys.MACHINE, "sys-root", "mingw", "bin")
    ipoptlibdir = cbclibdir
end

@osx_only begin
    using Homebrew
    provides(Homebrew.HB, "Optimizationservices", [libOS], os = :Darwin)
    cbclibdir = joinpath(Homebrew.prefix(), "lib")
    ipoptlibdir = cbclibdir
end

@linux_only begin
    # should probably be using deps/deps.jl for these
    cbclibdir = Pkg.dir("Cbc", "deps", "usr", "lib")
    ipoptlibdir = Pkg.dir("Ipopt", "deps", "usr", "lib")
end

prefix = joinpath(BinDeps.depsdir(libOS), "usr")
patchdir = BinDeps.depsdir(libOS)
builddir = joinpath(BinDeps.depsdir(libOS), "src", "OS-$version", "build")

ENV2 = copy(ENV)
@unix_only ENV2["PKG_CONFIG_PATH"] = string(joinpath(cbclibdir, "pkgconfig"),
    ":", joinpath(ipoptlibdir, "pkgconfig"))
cbcincdir = joinpath(cbclibdir, "..", "include", "coin")

provides(SimpleBuild,
    (@build_steps begin
        GetSources(libOS)
        CreateDirectory(builddir, true)
        @build_steps begin
            ChangeDirectory(builddir)
            pipeline(`cat $patchdir/os-printlevel.patch`, `patch -p1 -d ..`)
            setenv(`../configure --prefix=$prefix --enable-dependency-linking
                coin_skip_warn_cflags=yes coin_skip_warn_cxxflags=yes coin_skip_warn_fflags=yes
                --with-coinutils-lib="-L$cbclibdir -lCoinUtils"
                --with-coinutils-incdir=$cbcincdir
                --with-osi-lib="-L$cbclibdir -lOsi -lCoinUtils"
                --with-osi-incdir=$cbcincdir
                --with-clp-lib="-L$cbclibdir -lClp -lOsiClp"
                --with-clp-incdir=$cbcincdir
                --with-cgl-lib="-L$cbclibdir -lCgl"
                --with-cgl-incdir=$cbcincdir
                --with-cbc-lib="-L$cbclibdir -lCbc"
                --with-cbc-incdir=$cbcincdir
                --with-blas="-L$ipoptlibdir -lcoinblas"
                --with-lapack="-L$ipoptlibdir -lcoinlapack"
                --with-mumps-lib="-L$ipoptlibdir -lcoinmumps"
                --with-ipopt-lib="-L$ipoptlibdir -lipopt"`, ENV2)
            `make`
            `make -j1 install`
            `make -C OS/test alltests`
        end
    end), [libOS], os = :Unix)

@BinDeps.install Dict([(:libOS, :libOS)])
