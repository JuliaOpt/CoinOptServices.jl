using BinDeps

@BinDeps.setup

libOS = library_dependency("libOS")
version = "2.8.4"

provides(Sources, URI("http://www.coin-or.org/download/source/OS/OS-$version.tgz"),
    [libOS], os = :Unix)

@windows_only begin
    #using WinRPM
    #provides(WinRPM.RPM, "OptimizationServices", [libOS], os = :Windows)
    # TODO until WinRPM is all ready, download win32 binary of CoinAll?
    # May be impossible to satisfy BinDeps library_dependency for win64 Julia in that case
end

@osx_only begin
    #using Homebrew
    #provides(Homebrew.HB, "OptimizationServices", [libOS], os = :Darwin)
end

prefix = joinpath(BinDeps.depsdir(libOS), "usr")
patchdir = BinDeps.depsdir(libOS)
srcdir = joinpath(BinDeps.depsdir(libOS), "src", "OS-$version")

rpath = ""
@linux_only rpath = "LDFLAGS=-Wl,--rpath,$(joinpath(prefix,"lib"))"

provides(SimpleBuild,
    (@build_steps begin
        GetSources(libOS)
        @build_steps begin
            ChangeDirectory(srcdir)
            @build_steps begin
                ChangeDirectory(joinpath(srcdir, "ThirdParty", "ASL"))
                `./get.ASL`
            end
            @build_steps begin
                ChangeDirectory(joinpath(srcdir, "ThirdParty", "Blas"))
                `./get.Blas`
            end
            @build_steps begin
                ChangeDirectory(joinpath(srcdir, "ThirdParty", "Lapack"))
                `./get.Lapack`
            end
            @build_steps begin
                ChangeDirectory(joinpath(srcdir, "ThirdParty", "Mumps"))
                `./get.Mumps`
            end
            `cat $patchdir/OS-clang.patch` |> `patch -p1`
            `./configure --prefix=$prefix --enable-dependency-linking $rpath
                coin_skip_warn_cflags=yes coin_skip_warn_cxxflags=yes coin_skip_warn_fflags=yes`
            `make` |> "make.log"
            `make -j1 install`
            `make test`
        end
    end), [libOS], os = :Unix)

@BinDeps.install [:libOS => :libOS]
