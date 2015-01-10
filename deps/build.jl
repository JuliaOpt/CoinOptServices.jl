using BinDeps

@BinDeps.setup

libOS = library_dependency("libOS")
version = "2.8.4"

provides(Sources, URI("http://www.coin-or.org/download/source/OS/OS-$version.tgz"),
    [libOS], os = :Unix)

@windows_only begin
    #using WinRPM
    #provides(WinRPM.RPM, "OptimizationServices", [libOS], os = :Windows)
end

@osx_only begin
    #using Homebrew
    #provides(Homebrew.HB, "OptimizationServices", [libOS], os = :Darwin)
end

prefix = joinpath(BinDeps.depsdir(libOS), "usr")
patchdir = BinDeps.depsdir(libOS)
srcdir = joinpath(BinDeps.depsdir(libOS), "src", "OS-$version")

provides(SimpleBuild,
    (@build_steps begin
        GetSources(libOS)
        @build_steps begin
            ChangeDirectory(srcdir)
            `cat $patchdir/OS-clang.patch` |> `patch -p1`
            `./configure --prefix=$prefix --enable-dependency-linking`
            `make install`
        end
    end), [libOS], os = :Unix)

@BinDeps.install [:libOS => :libOS]
