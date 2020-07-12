;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2013 Cyril Roelandt <tipecaml@gmail.com>
;;; Copyright © 2014, 2015 David Thompson <davet@gnu.org>
;;; Copyright © 2014 Kevin Lemonnier <lemonnierk@ulrar.net>
;;; Copyright © 2015 Jeff Mickey <j@codemac.net>
;;; Copyright © 2016, 2017, 2018, 2019, 2020 Tobias Geerinckx-Rice <me@tobias.gr>
;;; Copyright © 2016 Stefan Reichör <stefan@xsteve.at>
;;; Copyright © 2017, 2018 Ricardo Wurmus <rekado@elephly.net>
;;; Copyright © 2017, 2018 Nikita <nikita@n0.is>
;;; Copyright © 2017, 2018 Leo Famulari <leo@famulari.name>
;;; Copyright © 2017 Arun Isaac <arunisaac@systemreboot.net>
;;; Copyright © 2019 Meiyo Peng <meiyo.peng@gmail.com>
;;; Copyright © 2019 Timothy Sample <samplet@ngyro.com>
;;; Copyright © 2019 Mathieu Othacehe <m.othacehe@gmail.com>
;;; Copyright © 2019, 2020 Jan (janneke) Nieuwenhuizen <janneke@gnu.org>
;;; Copyright © 2020 Brice Waegeneire <brice@waegenei.re>
;;; Copyright © 2020 Ryan Prior <rprior@protonmail.com>
;;; Copyright © 2020 Efraim Flashner <efraim@flashner.co.il>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (gnu packages shells)
  #:use-module (gnu packages)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages bison)
  #:use-module (gnu packages documentation)
  #:use-module (gnu packages groff)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages libbsd)
  #:use-module (gnu packages libedit)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages ncurses)
  #:use-module (gnu packages pcre)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages readline)
  #:use-module (gnu packages scheme)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system python)
  #:use-module (guix build-system trivial)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix licenses)
  #:use-module (guix packages)
  #:use-module (guix utils))

(define-public dash
  (package
    (name "dash")
    (version "0.5.11.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "http://gondor.apana.org.au/~herbert/dash/files/"
                           "dash-" version ".tar.gz"))
       (sha256
        (base32 "048n1rbw3v1ffzsw5mkc6zzvvf1csq7pcri7jraaqag38vqq3j3k"))
       (modules '((guix build utils)))
       (snippet
        '(begin
           ;; The man page hails from BSD, where (d)ash is the default shell.
           ;; This isn't the case on Guix or indeed most other GNU systems.
           (substitute* "src/dash.1"
             (("the standard command interpreter for the system")
              "a command interpreter based on the original Bourne shell"))
           #t))))
    (build-system gnu-build-system)
    (inputs
     `(("libedit" ,libedit)))
    (arguments
     '(#:configure-flags '("--with-libedit")))
    (home-page "http://gondor.apana.org.au/~herbert/dash")
    (synopsis "POSIX-compliant shell optimised for size")
    (description
     "dash is a POSIX-compliant @command{/bin/sh} implementation that aims to be
as small as possible, often without sacrificing speed.  It is faster than the
GNU Bourne-Again Shell (@command{bash}) at most scripted tasks.  dash is a
direct descendant of NetBSD's Almquist Shell (@command{ash}).")
    (license (list bsd-3
                   gpl2+))))    ; mksignames.c

(define-public fish
  (package
    (name "fish")
    (version "3.1.2")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/fish-shell/fish-shell/"
                           "releases/download/" version "/"
                           "fish-" version ".tar.gz"))
       (sha256
        (base32 "1vblmb3x2k2cb0db5jdyflppnlqsm7i6jjaidyhmvaaw7ch2gffm"))
       (modules '((guix build utils)))
       (snippet
        '(begin
           (delete-file-recursively "pcre2-10.32") #t))))
    (build-system cmake-build-system)
    (inputs
     `(("fish-foreign-env" ,fish-foreign-env)
       ("ncurses" ,ncurses)
       ("pcre2" ,pcre2)      ; don't use the bundled PCRE2
       ("python" ,python)))  ; for fish_config and manpage completions
    (native-inputs
     `(("doxygen" ,doxygen)
       ; for 'fish --help'
       ("groff" ,groff)))
    (arguments
     '(#:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'set-env
           (lambda _
             ;; some tests write to $HOME
             (setenv "HOME" (getcwd))
             #t))
         (add-after 'unpack 'patch-tests
           (lambda* (#:key inputs #:allow-other-keys)
             (let ((coreutils (assoc-ref inputs "coreutils"))
                   (bash (assoc-ref inputs "bash")))
               ;; This test fails
               (delete-file "tests/checks/pipeline-pgroup.fish")
               ;; These try to open a terminal
               (delete-file "tests/checks/interactive.fish")
               (delete-file "tests/checks/login-interactive.fish")
               ;; These contain absolute path references
               (substitute* "src/fish_tests.cpp"
                 (("/bin/echo" echo) (string-append coreutils echo))
                 (("/bin/ca" ca) (string-append coreutils ca))
                 (("\"(/bin/c)\"" _ c) (string-append "\"" coreutils c "\""))
                 (("/bin/ls_not_a_path" ls-not-a-path)
                  (string-append coreutils ls-not-a-path))
                 (("/bin/ls" ls) (string-append coreutils ls))
                 (("(/bin/)\"" _ bin) (string-append coreutils bin "\""))
                 (("/bin -" bin) (string-append coreutils bin))
                 (((string-append
                    "do_test\\(is_potential_path\\("
                    "L\"/usr\", wds, vars, PATH_REQUIRE_DIR\\)\\);"))
                  ""))
               (substitute*
                 (append (find-files "tests" ".*\\.(in|out|err)$")
                         (find-files "tests/checks" ".*\\.fish"))
                 (("/bin/pwd" pwd) (string-append coreutils pwd))
                 (("/bin/echo" echo) (string-append coreutils echo))
                 (("/bin/sh" sh) (string-append bash sh))
                 (("/bin/ls" ls) (string-append coreutils ls)))
               (substitute* (find-files "tests" ".*\\.(in|out|err)$")
                 (("/usr/bin") (string-append coreutils "/bin")))
               #t)))
         ;; Source /etc/fish/config.fish from $__fish_sysconf_dir/config.fish.
         (add-after 'patch-tests 'patch-fish-config
           (lambda _
             (let ((port (open-file "etc/config.fish" "a")))
               (display (string-append
                         "\n\n"
                         "# Patched by Guix.\n"
                         "# Source /etc/fish/config.fish.\n"
                         "if test -f /etc/fish/config.fish\n"
                         "    source /etc/fish/config.fish\n"
                         "end\n")
                        port)
               (close-port port))
             #t))
         ;; Embed absolute paths.
         (add-before 'install 'embed-absolute-paths
           (lambda _
             (substitute* "share/functions/__fish_print_help.fish"
               (("nroff") (which "nroff")))
             #t))
         ;; Enable completions, functions and configurations in user's and
         ;; system's guix profiles by adding them to __extra_* variables.
         (add-before 'install 'patch-fish-extra-paths
           (lambda _
             (let ((port (open-file "share/__fish_build_paths.fish" "a")))
               (display
                (string-append
                 "\n\n"
                 "# Patched by Guix.\n"
                 "# Enable completions, functions and configurations in user's"
                 " and system's guix profiles by adding them to __extra_*"
                 " variables.\n"
                 "set -l __guix_profile_paths ~/.guix-profile"
                 " /run/current-system/profile\n"
                 "set __extra_completionsdir"
                 " $__guix_profile_paths\"/etc/fish/completions\""
                 " $__guix_profile_paths\"/share/fish/vendor_completions.d\""
                 " $__extra_completionsdir\n"
                 "set __extra_functionsdir"
                 " $__guix_profile_paths\"/etc/fish/functions\""
                 " $__guix_profile_paths\"/share/fish/vendor_functions.d\""
                 " $__extra_functionsdir\n"
                 "set __extra_confdir"
                 " $__guix_profile_paths\"/etc/fish/conf.d\""
                 " $__guix_profile_paths\"/share/fish/vendor_conf.d\""
                 " $__extra_confdir\n")
                port)
               (close-port port))
             #t))
         ;; Use fish-foreign-env to source /etc/profile.
         (add-before 'install 'source-etc-profile
           (lambda* (#:key inputs #:allow-other-keys)
             (let ((port (open-file "share/__fish_build_paths.fish" "a")))
               (display
                (string-append
                 "\n\n"
                 "# Patched by Guix.\n"
                 "# Use fish-foreign-env to source /etc/profile.\n"
                 "if status is-login\n"
                 "    set fish_function_path "
                 (assoc-ref inputs "fish-foreign-env") "/share/fish/functions"
                 " $__fish_datadir/functions\n"
                 "    fenv source /etc/profile\n"
                 "    set -e fish_function_path\n"
                 "end\n")
                port)
               (close-port port))
             #t)))))
    (synopsis "The friendly interactive shell")
    (description
     "Fish (friendly interactive shell) is a shell focused on interactive use,
discoverability, and friendliness.  Fish has very user-friendly and powerful
tab-completion, including descriptions of every completion, completion of
strings with wildcards, and many completions for specific commands.  It also
has extensive and discoverable help.  A special @command{help} command gives
access to all the fish documentation in your web browser.  Other features
include smart terminal handling based on terminfo, an easy to search history,
and syntax highlighting.")
    (home-page "https://fishshell.com/")
    (license gpl2)))

(define-public fish-foreign-env
  (package
    (name "fish-foreign-env")
    (version "0.20190116")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/oh-my-fish/plugin-foreign-env.git")
             (commit "dddd9213272a0ab848d474d0cbde12ad034e65bc")))
       (file-name (git-file-name name version))
       (sha256
        (base32 "00xqlyl3lffc5l0viin1nyp819wf81fncqyz87jx8ljjdhilmgbs"))))
    (build-system trivial-build-system)
    (arguments
     '(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((source (assoc-ref %build-inputs "source"))
                (out (assoc-ref %outputs "out"))
                (func-path (string-append out "/share/fish/functions")))
           (mkdir-p func-path)
           (copy-recursively (string-append source "/functions")
                             func-path)

           ;; Embed absolute paths.
           (substitute* `(,(string-append func-path "/fenv.fish")
                          ,(string-append func-path "/fenv.apply.fish")
                          ,(string-append func-path "/fenv.main.fish"))
             (("bash")
              (string-append (assoc-ref %build-inputs "bash") "/bin/bash"))
             (("sed")
              (string-append (assoc-ref %build-inputs "sed") "/bin/sed"))
             ((" tr ")
              (string-append " " (assoc-ref %build-inputs "coreutils")
                             "/bin/tr ")))))))
    (inputs
     `(("bash" ,bash)
       ("coreutils" ,coreutils)
       ("sed" ,sed)))
    (home-page "https://github.com/oh-my-fish/plugin-foreign-env")
    (synopsis "Foreign environment interface for fish shell")
    (description "@code{fish-foreign-env} wraps bash script execution in a way
that environment variables that are exported or modified get imported back
into fish.")
    (license expat)))

(define-public rc
  (package
    (name "rc")
    (version "1.7.4")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/rakitzis/rc.git")
                    (commit (string-append "v" version))))
              (sha256
               (base32
                "0vj1h4pcg13vxsiydmmk87dr2sra9h4gwx0c4q6fjsiw4in78rrd"))
              (file-name (git-file-name name version))))
    (build-system gnu-build-system)
    (arguments
     `(#:configure-flags
       '("--with-edit=gnu")
       #:phases
       (modify-phases %standard-phases
         (add-before 'bootstrap 'patch-trip.rc
          (lambda _
            (substitute* "trip.rc"
              (("/bin/pwd") (which "pwd"))
              (("/bin/sh")  (which "sh"))
              (("/bin/rm")  (which "rm"))
              (("/bin\\)")  (string-append (dirname (which "rm")) ")")))
            #t)))))
    (inputs `(("readline" ,readline)
              ("perl" ,perl)))
    (native-inputs `(("autoconf" ,autoconf)
                     ("automake" ,automake)
                     ("libtool" ,libtool)
                     ("pkg-config" ,pkg-config)))
    (synopsis "Alternative implementation of the rc shell by Byron Rakitzis")
    (description
     "This is a reimplementation by Byron Rakitzis of the Plan 9 shell.  It
has a small feature set similar to a traditional Bourne shell.")
    (home-page "https://github.com/rakitzis/rc")
    (license zlib)))

(define-public es
  (package
    (name "es")
    (version "0.9.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/wryun/es-shell/releases/"
                           "download/v" version "/es-" version ".tar.gz"))
       (sha256
        (base32
         "1fplzxc6lncz2lv2fyr2ig23rgg5j96rm2bbl1rs28mik771zd5h"))
       (file-name (string-append name "-" version ".tar.gz"))))
    (build-system gnu-build-system)
    (arguments
     `(#:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 're-enter-rootdir
           ;; The tarball has no folder.
           (lambda _
             (chdir ".."))))))
    (inputs
     `(("readline" ,readline)))
    (native-inputs
     `(("bison" ,bison)))
    (synopsis "Extensible shell with higher-order functions")
    (description
     "Es is an extensible shell.  The language was derived from the Plan 9
shell, rc, and was influenced by functional programming languages, such as
Scheme, and the Tcl embeddable programming language.  This implementation is
derived from Byron Rakitzis's public domain implementation of rc, and was
written by Paul Haahr and Byron Rakitzis.")
    (home-page "https://wryun.github.io/es-shell/")
    (license public-domain)))

(define-public tcsh
  (package
    (name "tcsh")
    (version "6.22.02")
    (source (origin
              (method url-fetch)
              ;; Old tarballs are moved to old/.
              (uri (list (string-append "ftp://ftp.astron.com/pub/tcsh/"
                                        "tcsh-" version ".tar.gz")
                         (string-append "ftp://ftp.astron.com/pub/tcsh/"
                                        "old/tcsh-" version ".tar.gz")))
              (sha256
               (base32
                "0nw8prz1n0lmr82wnpyhrzmki630afn7p9cfgr3vl00vr9c72a7d"))
              (patches (search-patches "tcsh-fix-autotest.patch"))
              (patch-flags '("-p0"))))
    (build-system gnu-build-system)
    (native-inputs
     `(("autoconf" ,autoconf)
       ("perl" ,perl)))
    (inputs
     `(("ncurses" ,ncurses)))
    (arguments
     `(#:phases
        (modify-phases %standard-phases
          ,@(if (%current-target-system)
                '((add-before 'configure 'set-cross-cc
                     (lambda _
                       (substitute* "configure"
                         (("CC_FOR_GETHOST=\"cc\"")
                          "CC_FOR_GETHOST=\"gcc\""))
                       #t)))
                '())
          (add-before 'check 'patch-test-scripts
            (lambda _
              ;; Take care of pwd
              (substitute* '("tests/commands.at" "tests/variables.at")
                (("/bin/pwd") (which "pwd")))
              ;; The .at files create shell scripts without shebangs. Erk.
              (substitute* "tests/commands.at"
                (("./output.sh") "/bin/sh output.sh"))
              (substitute* "tests/syntax.at"
                (("; other_script.csh") "; /bin/sh other_script.csh"))
              ;; Now, let's generate the test suite and patch it
              (invoke "make" "tests/testsuite")

              ;; This file is ISO-8859-1 encoded.
              (with-fluids ((%default-port-encoding #f))
                (substitute* "tests/testsuite"
                  (("/bin/sh") (which "sh"))))
              #t))
          (add-after 'install 'post-install
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let* ((out (assoc-ref %outputs "out"))
                     (bin (string-append out "/bin")))
                (with-directory-excursion bin
                  (symlink "tcsh" "csh"))
                #t))))))
    (home-page "https://www.tcsh.org/")
    (synopsis "Unix shell based on csh")
    (description
     "Tcsh is an enhanced, but completely compatible version of the Berkeley
UNIX C shell (csh).  It is a command language interpreter usable both as an
interactive login shell and a shell script command processor.  It includes a
command-line editor, programmable word completion, spelling correction, a
history mechanism, job control and a C-like syntax.")
    (license bsd-4)))

(define-public zsh
  (package
    (name "zsh")
    (version "5.8")
    (source (origin
              (method url-fetch)
              (uri (list (string-append
                           "https://www.zsh.org/pub/zsh-" version
                           ".tar.xz")
                         (string-append
                           "https://www.zsh.org/pub/old/zsh-" version
                           ".tar.xz")))
              (sha256
               (base32
                "09yyaadq738zlrnlh1hd3ycj1mv3q5hh4xl1ank70mjnqm6bbi6w"))))
    (build-system gnu-build-system)
    (arguments `(#:configure-flags
                 `("--with-tcsetpgrp"
                  "--enable-pcre"
                  "--enable-maildir-support"
                  ;; share/zsh/site-functions isn't populated
                  "--disable-site-fndir"
                  ,(string-append
                    "--enable-additional-fpath="
                    "/usr/local/share/zsh/site-functions," ; for foreign OS
                    "/run/current-system/profile/share/zsh/site-functions"))
                 #:phases
                 (modify-phases %standard-phases
                   (add-before 'configure 'fix-sh
                     (lambda _
                       ;; Some of the files are ISO-8859-1 encoded.
                       (with-fluids ((%default-port-encoding #f))
                                    (substitute*
                                        '("configure"
                                          "configure.ac"
                                          "Src/exec.c"
                                          "Src/mkmakemod.sh"
                                          "Config/installfns.sh"
                                          "Config/defs.mk.in"
                                          "Test/E01options.ztst"
                                          "Test/A05execution.ztst"
                                          "Test/A01grammar.ztst"
                                          "Test/A06assign.ztst"
                                          "Test/B02typeset.ztst"
                                          "Completion/Unix/Command/_init_d"
                                          "Util/preconfig")
                                      (("/bin/sh") (which "sh"))))))
                   (add-before 'check 'patch-test
                     (lambda _
                       ;; In Zsh, `command -p` searches a predefined set of
                       ;; paths that don't exist in the build environment. See
                       ;; the assignment of 'path' in Src/init.c'
                       (substitute* "Test/A01grammar.ztst"
                         (("command -pv") "command -v")
                         (("command -p") "command ")
                         (("'command' -p") "'command' "))
                       #t)))))
    (native-inputs `(("autoconf" ,autoconf)))
    (inputs `(("ncurses" ,ncurses)
              ("pcre" ,pcre)
              ("perl" ,perl)))
    (synopsis "Powerful shell for interactive use and scripting")
    (description "The Z shell (zsh) is a Unix shell that can be used
as an interactive login shell and as a powerful command interpreter
for shell scripting.  Zsh can be thought of as an extended Bourne shell
with a large number of improvements, including some features of bash,
ksh, and tcsh.")
    (home-page "https://www.zsh.org/")

    ;; The whole thing is under an MIT/X11-style license, but there's one
    ;; command, 'Completion/Unix/Command/_darcs', which is under GPLv2+.
    (license gpl2+)))

(define-public xonsh
  (package
    (name "xonsh")
    (version "0.9.18")
    (source
      (origin
        (method url-fetch)
        (uri (pypi-uri "xonsh" version))
        (sha256
          (base32
            "1h4rrwzwiwkyi9p49sjn97rl39fqq2r23hchzsw0s3fcwa7m8fkj"))
        (modules '((guix build utils)))
        (snippet
         `(begin
            ;; Delete bundled PLY.
            (delete-file-recursively "xonsh/ply")
            (substitute* "setup.py"
              (("\"xonsh\\.ply\\.ply\",") ""))
            ;; Use our properly packaged PLY instead.
            (substitute* (list "setup.py"
                               "tests/test_lexer.py"
                               "xonsh/__amalgam__.py"
                               "xonsh/lexer.py"
                               "xonsh/parsers/base.py"
                               "xonsh/xonfig.py")
              (("from xonsh\\.ply\\.(.*) import" _ module)
               (format #f "from ~a import" module))
              (("from xonsh\\.ply import") "import"))
            #t))))
    (build-system python-build-system)
    (arguments
     '(;; TODO Try running run the test suite.
       ;; See 'requirements-tests.txt' in the source distribution for more
       ;; information.
       #:tests? #f))
    (inputs
     `(("python-ply" ,python-ply)))
    (home-page "https://xon.sh/")
    (synopsis "Python-ish shell")
    (description
     "Xonsh is a Python-ish, BASHwards-looking shell language and command
prompt.  The language is a superset of Python 3.4+ with additional shell
primitives that you are used to from Bash and IPython.  It works on all major
systems including Linux, Mac OSX, and Windows.  Xonsh is meant for the daily
use of experts and novices alike.")
    (license bsd-2)))

(define-public scsh
  (let ((commit "114432435e4eadd54334df6b37fcae505079b49f")
        (revision "1"))
    (package
      (name "scsh")
      (version (string-append "0.0.0-" revision "." (string-take commit 7)))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/scheme/scsh")
               (commit commit)))
         (file-name (string-append name "-" version "-checkout"))
         (sha256
          (base32
           "1ghk08akiz7hff1pndi8rmgamgcrn2mv9asbss9l79d3c2iaav3q"))))
      (build-system gnu-build-system)
      (arguments
       `(#:test-target "test"
         #:phases
         (modify-phases %standard-phases
           (add-before 'configure 'replace-rx
             (lambda* (#:key inputs #:allow-other-keys)
               (let* ((rx (assoc-ref inputs "scheme48-rx"))
                      (rxpath (string-append rx "/share/scheme48-"
                                             ,(package-version scheme48)
                                             "/rx")))
                 (delete-file-recursively "rx")
                 (symlink rxpath "rx"))
               #t)))))
      (inputs
       `(("scheme48" ,scheme48)
         ("scheme48-rx" ,scheme48-rx)))
      (native-inputs
       `(("autoconf" ,autoconf)
         ("automake" ,automake)))
      (home-page "https://github.com/scheme/scsh")
      (synopsis "Unix shell embedded in Scheme")
      (description
       "Scsh is a Unix shell embedded in Scheme.  Scsh has two main
components: a process notation for running programs and setting up pipelines
and redirections, and a complete syscall library for low-level access to the
operating system.")
      (license bsd-3))))

(define-public linenoise
  (let ((commit "2105ce445821381cf1bca87b6d386d4ea88ee20d")
        (revision "1"))
    (package
      (name "linenoise")
      (version (string-append "1.0-" revision "." (string-take commit 7)))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/antirez/linenoise")
               (commit commit)))
         (file-name (string-append name "-" version "-checkout"))
         (sha256
          (base32
           "1z16qwix8z6a40fskdgxsibkqgdrp4q6ncp4n6hnv4r9iihy2d8r"))))
      (build-system gnu-build-system)
      (arguments
       `(#:tests? #f                    ; no tests are included
         #:make-flags
         (list ,(string-append "CC=" (cc-for-target)))
         #:phases
         (modify-phases %standard-phases
           (delete 'configure)
           (replace 'install
             (lambda* (#:key outputs #:allow-other-keys)
               ;; At the moment there is no 'make install' in upstream.
               (let* ((out (assoc-ref outputs "out")))
                 (install-file "linenoise.h"
                               (string-append out "/include/linenoise"))
                 (install-file "linenoise.c"
                               (string-append out "/include/linenoise"))
                 #t))))))
      (home-page "https://github.com/antirez/linenoise")
      (synopsis "Minimal zero-config readline replacement")
      (description
       "Linenoise is a minimal, zero-config, readline replacement.
Its features include:

@enumerate
@item Single and multi line editing mode with the usual key bindings
@item History handling
@item Completion
@item Hints (suggestions at the right of the prompt as you type)
@item A subset of VT100 escapes, ANSI.SYS compatible
@end enumerate\n")
      (license bsd-2))))

(define-public s-shell
  (let ((commit "da2e5c20c0c5f477ec3426dc2584889a789b1659")
        (revision "2"))
    (package
      (name "s-shell")
      (version (git-version "0.0.0" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/rain-1/s")
               (commit commit)))
         (file-name (string-append name "-" version "-checkout"))
         (sha256
          (base32
           "0qiny71ww5nhzy4mnc8652hn0mlxyb67h333gbdxp4j4qxsi13q4"))))
      (build-system gnu-build-system)
      (inputs
       `(("linenoise" ,linenoise)))
      (arguments
       `(#:tests? #f
         #:make-flags (list "CC=gcc"
                            (string-append "PREFIX="
                                           (assoc-ref %outputs "out")))
         #:phases
         (modify-phases %standard-phases
           (add-after 'unpack 'install-directory-fix
             (lambda* (#:key outputs #:allow-other-keys)
               (let* ((out (assoc-ref outputs "out"))
                      (bin (string-append out "/bin")))
                 (substitute* "Makefile"
                   (("out") bin))
                 #t)))
           (add-after 'install 'manpage
             (lambda* (#:key outputs #:allow-other-keys)
               (install-file "s.1" (string-append (assoc-ref outputs "out")
                                                  "/share/man/man1"))))
           (replace 'configure
             (lambda* (#:key inputs outputs #:allow-other-keys)
               ;; At this point linenoise is meant to be included,
               ;; so we have to really copy it into the working directory
               ;; of s.
               (let* ((linenoise (assoc-ref inputs "linenoise"))
                      (noisepath (string-append linenoise "/include/linenoise"))
                      (out (assoc-ref outputs "out")))
                 (copy-recursively noisepath "linenoise")
                 (substitute* "s.c"
                   (("/bin/s") (string-append out "/bin/s")))
                 #t))))))
      (home-page "https://github.com/rain-1/s")
      (synopsis "Extremely minimal shell with the simplest syntax possible")
      (description
       "S is a new shell that aims to be extremely simple.
S does not implemnt the POSIX shell standard.
There are no globs or \"splatting\" where a variable $FOO turns into multiple
command line arguments.  One token stays one token forever.
This is a \"no surprises\" straightforward approach.

There are no redirection operators > in the shell language, they are added as
extra programs.  > is just another unix command, < is essentially cat(1).
A @code{andglob} program is also provided along with s.")
      (license bsd-3))))

(define-public oksh
  (package
    (name "oksh")
    (version "0.5.9")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://connochaetos.org/oksh/oksh-"
                           version ".tar.gz"))
       (sha256
        (base32
         "0ln9yf6pxngsviqszv8klnnvn8vcpplvj1njdn8xr2y8frkbw8r3"))))
    (build-system gnu-build-system)
    (arguments
     `(; The test files are not part of the distributed tarball.
       #:tests? #f))
    (home-page "https://connochaetos.org/oksh")
    (synopsis "Port of OpenBSD Korn Shell")
    (description
     "Oksh is a port of the OpenBSD Korn Shell.
The OpenBSD Korn Shell is a cleaned up and enhanced ksh.")
    (license gpl3+)))

(define-public loksh
  (package
    (name "loksh")
    (version "6.6")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/dimkr/loksh.git")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1a8s64n97ikvvi7ckirxnnjvcmhr3dd4rnqm2ivapyzb0wp42jk7"))))
    (build-system gnu-build-system)
    (inputs
     `(("libbsd" ,libbsd)
       ("ncurses" ,ncurses)))
    (native-inputs
     `(("pkg-config" ,pkg-config)))
    (arguments
     `(#:tests? #f                      ; no tests included
       #:make-flags (list "CC=gcc" "HAVE_LIBBSD=1"
                          (string-append "PREFIX="
                                         (assoc-ref %outputs "out")))
       #:phases
       (modify-phases %standard-phases
         (delete 'configure))))         ; no configure script
    (home-page "https://github.com/dimkr/loksh")
    (synopsis "Korn Shell from OpenBSD")
    (description
     "loksh is a Linux port of OpenBSD's @command{ksh}.  It is a small,
interactive POSIX shell targeted at resource-constrained systems.")
    ;; The file 'LEGAL' says it is the public domain, and the 2
    ;; exceptions which are listed are not included in this port.
    (license public-domain)))

(define-public mksh
  (package
    (name "mksh")
    (version "58")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://www.mirbsd.org/MirOS/dist/mir/mksh/mksh-R"
                           version ".tgz"))
       (sha256
        (base32 "1337zjvzh14yncg9igdry904a3ns52l8rnm1kcq262w7f5xyp2v0"))))
    (build-system gnu-build-system)
    (arguments
     `(#:tests? #f                      ; tests require access to /dev/tty
       #:phases
       (modify-phases %standard-phases
         (delete 'configure)
         (replace 'build
           (lambda _
             (setenv "CC" "gcc")
             (invoke (which "sh") "Build.sh")))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (bin (string-append out "/bin"))
                    (man (string-append out "/share/man/man1")))
               (install-file "mksh" bin)
               (with-directory-excursion bin
                 (symlink "mksh" "ksh"))
               (install-file "mksh.1" man)
               #t))))))
    (home-page "https://www.mirbsd.org/mksh.htm")
    (synopsis "Korn Shell from MirBSD")
    (description "mksh is an actively developed free implementation of the
Korn Shell programming language and a successor to the Public Domain Korn
Shell (pdksh).")
    (license (list miros
                   isc))))              ; strlcpy.c

(define-public oil
  (package
    (name "oil")
    ;; https://www.oilshell.org/blog/2020/04/release-0.8.pre4.html#comment-on-version-numbering
    (version "0.8.pre6")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://www.oilshell.org/download/oil-"
                           version ".tar.gz"))
       (sha256
        (base32 "11nfwn5b1w74hv78065jg2zm45mqzi59381b0f649j7n3g7yp3iq"))))
    (build-system gnu-build-system)
    (arguments
     `(#:strip-binaries? #f             ; strip breaks the binary
       #:phases
       (modify-phases %standard-phases
         (replace 'configure
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((out (assoc-ref outputs "out")))
               (setenv "CC" "gcc")
               (substitute* "configure"
                 ((" cc ") " $CC "))
               (invoke "./configure" (string-append "--prefix=" out)
                       "--with-readline"))))
         (replace 'check
           ;; The tests are not distributed in the tarballs but upstream
           ;; recommends running this smoke test.
           ;; https://github.com/oilshell/oil/blob/release/0.8.pre6/INSTALL.txt#L38-L48
           (lambda _
             (let* ((oil "_bin/oil.ovm"))
               (invoke/quiet oil "osh" "-c" "echo hi")
               (invoke/quiet oil "osh" "-n" "configure")))))))
    (inputs
     `(("readline" ,readline)))
    (home-page "https://www.oilshell.org")
    (synopsis "Programming language and Bash-compatible Unix shell")
    (description "Oil is a programming language with automatic translation for
Bash.  It includes osh, a Unix/POSIX shell that runs unmodified Bash
scripts.")
    (license (list psfl                 ; tarball includes python2.7
                   asl2.0))))

(define-public oil-shell
  (deprecated-package "oil-shell" oil))

(define-public gash
  (package
    (name "gash")
    (version "0.2.0")
    (source
     (origin (method url-fetch)
             (uri (string-append "mirror://savannah/gash/gash-"
                                 version ".tar.gz"))
             (sha256
              (base32
               "13m0yz5h9nj3x40mr6wr5xcpq1lscndfwcicw3skrz801025hhgf"))
             (modules '((guix build utils)))
             (snippet
              '(begin
                 ;; Allow builds with Guile 3.0.
                 (substitute* "configure"
                   (("search=\"2\\.2 2\\.0\"")
                    "search=\"3.0 2.2 2.0\""))
                 #t))))
    (build-system gnu-build-system)
    (native-inputs
     `(("pkg-config" ,pkg-config)))
    (inputs
     `(("guile" ,guile-3.0)))
    (arguments
     '(#:make-flags '("XFAIL_TESTS=tests/redirects.org")))
    (home-page "https://savannah.nongnu.org/projects/gash/")
    (synopsis "POSIX-compatible shell written in Guile Scheme")
    (description "Gash is a POSIX-compatible shell written in Guile
Scheme.  It provides both the shell interface, as well as a Guile
library for parsing shell scripts.  Gash is designed to bootstrap Bash
as part of the Guix bootstrap process.")
    (license gpl3+)))

(define-public gash-utils
  (package
    (name "gash-utils")
    (version "0.1.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://savannah/gash/gash-utils-"
                                  version ".tar.gz"))
              (sha256
               (base32
                "0ib2p52qmbac5n0s5bys4fiwim461ps546976l1n7pwbs0avh7fk"))
              (patches (search-patches "gash-utils-ls-test.patch"))
              (modules '((guix build utils)))
              (snippet
               '(begin
                  ;; Allow builds with Guile 3.0.
                  (substitute* "configure"
                    (("search=\"2\\.2 2\\.0\"")
                     "search=\"3.0 2.2 2.0\""))
                  #t))))
    (build-system gnu-build-system)
    (native-inputs
     `(("pkg-config" ,pkg-config)))
    (inputs
     `(("guile" ,guile-3.0)
       ("gash" ,gash)))
    (home-page "https://savannah.nongnu.org/projects/gash/")
    (synopsis "Core POSIX utilities written in Guile Scheme")
    (description "Gash-Utils provides Scheme implementations of many
common POSIX utilities (there are about 40 of them, ranging in
complexity from @command{false} to @command{awk}).  The utilities are
designed to be capable of bootstrapping their standard GNU counterparts.
Underpinning these utilities are many Scheme interfaces for manipulating
files and text.")
    (license gpl3+)))

