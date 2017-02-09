class Opencascade < Formula
  desc "3D modeling and numerical simulation software for CAD/CAM/CAE"
  homepage "https://dev.opencascade.org/"
  url "https://github.com/FreeCAD/homebrew-freecad/releases/download/0/opencascade-7.1.0.tgz"
  sha256 "8aaf1e29edc791ad611172dcbcc6efa35ada1e02a5eb7186a837131f85231d71"

  bottle do
    cellar :any
    rebuild 1
    sha256 "da00932812373c97b3fd41994a1a5cfbaf405ad8d48bf9697f52b0b07371bf56" => :sierra
    sha256 "4eb8fc77de51a75ec8c8372868fa6e1329d1ae58004fc326f8fff1d7d48b2d0d" => :el_capitan
    sha256 "bb4455c156a0942f0def7371b10950118724235f1aeb9acf7eed2910b2f277e9" => :yosemite
  end

  option "without-opencl", "Build without OpenCL support" if OS.mac?
  option "with-extras", "Install documentation (~17 MB), source files (~113 MB), samples and templates"
  option "with-test", "Install tests (~55MB)"
  deprecated_option "with-tests" => "with-test"

  depends_on "cmake" => :build
  depends_on "freetype"
  depends_on "doxygen" if build.with? "extras"
  depends_on "freeimage" => :recommended
  depends_on "gl2ps" => :recommended
  depends_on "tbb" => :recommended if OS.mac? # Couldn't make it find TBB...
  depends_on :macos => :snow_leopard

  conflicts_with "oce", :because => "OCE is a fork for patches/improvements/experiments over OpenCascade"

  def install
    # recent xcode stores it's sdk in the application folder
    sdk_path = Pathname.new `xcrun --show-sdk-path`.strip

    cmake_args = std_cmake_args
    cmake_args << "-DCMAKE_PREFIX_PATH:PATH=#{HOMEBREW_PREFIX}"
    cmake_args << "-DCMAKE_INCLUDE_PATH:PATH=#{HOMEBREW_PREFIX}/lib"
    cmake_args << "-DCMAKE_FRAMEWORK_PATH:PATH=#{HOMEBREW_PREFIX}/Frameworks" if OS.mac?
    cmake_args << "-DINSTALL_DIR:PATH=#{prefix}"
    cmake_args << "-D3RDPARTY_DIR:PATH=#{HOMEBREW_PREFIX}"
    cmake_args << "-D3RDPARTY_TCL_DIR:PATH=/usr"
    cmake_args << "-D3RDPARTY_TCL_INCLUDE_DIR:PATH=#{sdk_path}/usr/include/"
    cmake_args << "-D3RDPARTY_TK_INCLUDE_DIR:PATH=#{sdk_path}/usr/include/"
    cmake_args << "-DINSTALL_TESTS:BOOL=ON" if build.with? "tests"
    cmake_args << "-D3RDPARTY_TBB_DIR:PATH=#{HOMEBREW_PREFIX}" if build.with? "tbb"
    cmake_args << "-DINSTALL_SAMPLES=ON" if build.with? "extras"
    cmake_args << "-DINSTALL_DOC_Overview:BOOL=ON" if build.with? "extras"

    # must specify, otherwise finds old ft2config.h in /usr/X11R6
    cmake_args << "-D3RDPARTY_FREETYPE_INCLUDE_DIR:PATH=#{HOMEBREW_PREFIX}/include/freetype2" if OS.mac?

    %w[freeimage gl2ps tbb].each do |feature|
      cmake_args << "-DUSE_#{feature.upcase}:BOOL=ON" if build.with? feature
    end

    opencl_path = Pathname.new "#{sdk_path}/System/Library/Frameworks/OpenCL.framework/Versions/Current"
    if build.with?("opencl") && opencl_path.exist?
      cmake_args << "-D3RDPARTY_OPENCL_INCLUDE_DIR:PATH=#{opencl_path}/Headers"
      cmake_args << "-D3RDPARTY_OPENCL_DLL:FILEPATH=#{opencl_path}/Libraries/libcl2module.dylib"
    end

    mkdir "build" do
      system "cmake", "..", *cmake_args
      system "make", "install"

      if build.with? "extras"
        # Install the original source and adm scripts/templates
        prefix.install "../src"
        prefix.install "../adm"
        share.install_symlink prefix/"adm"
      else
        # Some apss expect resoures in legacy ${CASROOT}/src directory
        cd prefix do
          ln_s "share/opencascade/resources", "src"
        end
      end
    end

    # add symlinks to be able to compile against OpenCascade
    loc = OS.mac? ? "#{prefix}/mac64/clang" : "#{prefix}/lin64/gcc"
    bin.install_symlink Dir["#{loc}/bin/*"]
    lib.install_symlink Dir["#{loc}/lib/*"]
  end

  def caveats; <<-EOF.undent
    Some apps will require this enviroment variable:
      CASROOT=#{opt_prefix}

    On Linux make sure the following libraries are installed:
      sudo apt-get install libgl2ps-dev tcl8.6-dev tk8.6-dev libgl1-mesa-dev libglu1-mesa-dev libxmu-dev libxext-dev
    EOF
  end

  test do
    ENV["CASROOT"] = opt_prefix
    "1\n"==`#{bin}/DRAWEXE -c \"pload ALL\"`
  end
end
