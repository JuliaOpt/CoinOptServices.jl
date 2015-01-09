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

provides(SimpleBuild,
    (@build_steps begin
        GetSources(libOS)
        @build_steps begin
            ChangeDirectory(srcdir)
            `./configure --prefix=$prefix --enable-dependency-linking`
            `make install`
        end
    end), [libOS], os = :Unix)

@BinDeps.install [:libOS => :libOS]
