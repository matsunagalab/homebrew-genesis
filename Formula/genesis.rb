class Genesis < Formula
  desc "GENeralized-Ensemble SImulation System for molecular dynamics"
  homepage "https://www.r-ccs.riken.jp/labs/cbrt/"
  url "https://github.com/genesis-release-r-ccs/genesis/archive/refs/tags/v2.1.6.1.tar.gz"
  sha256 "fdc0e889590f198e2261105901c27718268a18a1cd32300e2232b457a7ba6761"
  license "LGPL-3.0-or-later"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "gcc"
  depends_on "open-mpi"
  depends_on "openblas"

  fails_with :clang do
    cause "GENESIS requires a Fortran compiler (gfortran)"
  end

  def install
    # GNU gcc version number (e.g. 15)
    gcc = Formula["gcc"]
    gcc_major = gcc.any_installed_version.major

    # Force MPI wrappers to use GNU compilers (not Apple clang)
    # so that OpenMP (-fopenmp) works correctly.
    ENV["OMPI_CC"]  = "gcc-#{gcc_major}"
    ENV["OMPI_CXX"] = "g++-#{gcc_major}"
    ENV["OMPI_FC"]  = "gfortran-#{gcc_major}"

    # Use MPI wrappers as the compilers for configure
    ENV["FC"]  = "mpif90"
    ENV["F77"] = "mpif90"
    ENV["CC"]  = "mpicc"
    ENV["CXX"] = "mpicxx"

    # Set FFLAGS to prevent configure.ac from overwriting FCFLAGS
    # with -march=native -ffast-math (not portable for Homebrew bottles).
    # configure.ac checks ac_test_FFLAGS to decide (configure.ac:925).
    # -fopenmp is omitted here: configure.ac adds it via OPT_OPENMP.
    ENV["FFLAGS"]  = "-O3 -ffree-line-length-none -fallow-argument-mismatch"
    ENV["FCFLAGS"] = "-O3 -ffree-line-length-none -fallow-argument-mismatch"
    ENV["CFLAGS"]  = "-O3"

    # Use OpenBLAS for LAPACK/BLAS
    ENV["LAPACK_LIBS"] = "-L#{Formula["openblas"].opt_lib} -lopenblas"

    # Use GNU cpp for Fortran preprocessing. The Homebrew shim's cpp is
    # clang-based and doesn't support the `cpp input output` positional
    # syntax that GENESIS Makefiles use.
    ENV["FPP"] = "#{Formula["gcc"].opt_bin}/cpp-#{gcc_major}"

    # configure.ac only sets PPFLAGS when FPP is exactly "cpp" (not a path).
    # -traditional-cpp prevents // in Fortran strings from being treated as
    # C++ line comments.
    ENV["PPFLAGS"] = "-traditional-cpp -traditional"

    # Fix missing comma in AC_ARG_ENABLE(qsimulate) in configure.ac.
    # Without this fix, --disable-qsimulate is silently ignored because
    # "enable_qsimulate=yes" is parsed as action-if-given instead of
    # action-if-not-given, so passing --disable still sets it to yes.
    inreplace "configure.ac",
              "enable QSimulate integration.])]",
              "enable QSimulate integration.])], "

    # Generate configure (not included in the tarball)
    system "autoreconf", "-fi"

    args = %W[
      --prefix=#{prefix}
      --enable-mpi
      --enable-openmp
      --enable-double
      --disable-qsimulate
    ]

    system "./configure", *args
    system "make", "-j#{ENV.make_jobs}"
    system "make", "install"

    # Install regression test data for `brew test` (~10 MB)
    # test.py uses relative paths to param/ and build/, so preserve directory structure.
    rt = pkgshare/"regression_test"
    rt.install "tests/regression_test/test.py"
    rt.install "tests/regression_test/genesis.py"
    (rt/"param").install "tests/regression_test/param/par_all27_prot_lipid.prm"
    (rt/"param").install "tests/regression_test/param/top_all27_prot_lipid.rtf"
    (rt/"build").install "tests/regression_test/build/jac_param27"
    rt.install "tests/regression_test/test_spdyn"
    rt.install "tests/regression_test/test_atdyn"
  end

  def caveats
    <<~EOS
      GENESIS has been installed with MPI support (Open MPI).
      To run parallel simulations:
        mpirun -np <nprocs> spdyn <input_file>

      For serial runs (atdyn only):
        atdyn <input_file>

      Regression tests are installed at:
        #{pkgshare}/regression_test/
      Run with:
        cd #{pkgshare}/regression_test
        OMP_NUM_THREADS=1 python3 test.py "mpirun -np 1 #{HOMEBREW_PREFIX}/bin/spdyn"
        OMP_NUM_THREADS=1 python3 test.py "mpirun -np 1 #{HOMEBREW_PREFIX}/bin/atdyn"

      Documentation: https://www.r-ccs.riken.jp/labs/cbrt/
    EOS
  end

  test do
    ENV["OMP_NUM_THREADS"] = "1"

    # Copy regression test data to a writable temp directory.
    # test.py writes output files (test, error) in the test case directory,
    # but the installed pkgshare is read-only.
    cp_r pkgshare/"regression_test", testpath/"regression_test"

    cd testpath/"regression_test" do
      system "python3", "test.py",
             "mpirun --oversubscribe -np 1 #{bin}/atdyn",
             "test_atdyn/jac_param27/CUTOFF"
      system "python3", "test.py",
             "mpirun --oversubscribe -np 1 #{bin}/spdyn",
             "test_spdyn/jac_param27/PME_opt_1dalltoall"
    end
  end
end
