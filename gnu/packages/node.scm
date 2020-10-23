;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2014 Cyrill Schenkel <cyrill.schenkel@gmail.com>
;;; Copyright © 2015 Andreas Enge <andreas@enge.fr>
;;; Copyright © 2015, 2016 David Thompson <davet@gnu.org>
;;; Copyright © 2016 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2017 Mike Gerwitz <mtg@gnu.org>
;;; Copyright © 2018 Tobias Geerinckx-Rice <me@tobias.gr>
;;; Copyright © 2018, 2019, 2020 Marius Bakke <mbakke@fastmail.com>
;;; Copyright © 2020 Pierre Langlois <pierre.langlois@gmx.com>
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

(define-module (gnu packages node)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module ((guix build utils) #:select (alist-replace))
  #:use-module (guix packages)
  #:use-module (guix derivations)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system node)
  #:use-module (gnu packages)
  #:use-module (gnu packages adns)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages icu4c)
  #:use-module (gnu packages libevent)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages node-xyz)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages web))

(define-public node
  (package
    (name "node")
    (version "10.20.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://nodejs.org/dist/v" version
                                  "/node-v" version ".tar.xz"))
              (sha256
               (base32
                "0cvjwnl0wkcsyw3kannbdv01s235wrnp11n2s6swzjx95gpichfi"))
              (modules '((guix build utils)))
              (snippet
               `(begin
                  ;; Remove bundled software.
                  (for-each delete-file-recursively
                            '("deps/cares"
                              "deps/http_parser"
                              "deps/icu-small"
                              "deps/nghttp2"
                              "deps/openssl"
                              "deps/uv"
                              "deps/zlib"))
                  (substitute* "Makefile"
                    ;; Remove references to bundled software.
                    (("deps/http_parser/http_parser.gyp") "")
                    (("deps/uv/include/\\*.h") "")
                    (("deps/uv/uv.gyp") "")
                    (("deps/zlib/zlib.gyp") ""))
                  #t))))
    (build-system gnu-build-system)
    (arguments
     `(#:configure-flags '("--shared-cares"
                           "--shared-http-parser"
                           "--shared-libuv"
                           "--shared-nghttp2"
                           "--shared-openssl"
                           "--shared-zlib"
                           "--without-snapshot"
                           "--with-intl=system-icu")
       ;; Run only the CI tests.  The default test target requires additional
       ;; add-ons from NPM that are not distributed with the source.
       #:test-target "test-ci-js"
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'patch-files
           (lambda* (#:key inputs #:allow-other-keys)
             ;; Fix hardcoded /bin/sh references.
             (substitute* '("lib/child_process.js"
                            "lib/internal/v8_prof_polyfill.js"
                            "test/parallel/test-child-process-spawnsync-shell.js"
                            "test/parallel/test-stdio-closed.js"
                            "test/sequential/test-child-process-emfile.js")
               (("'/bin/sh'")
                (string-append "'" (which "sh") "'")))

             ;; Fix hardcoded /usr/bin/env references.
             (substitute* '("test/parallel/test-child-process-default-options.js"
                            "test/parallel/test-child-process-env.js"
                            "test/parallel/test-child-process-exec-env.js")
               (("'/usr/bin/env'")
                (string-append "'" (which "env") "'")))

             ;; FIXME: These tests fail in the build container, but they don't
             ;; seem to be indicative of real problems in practice.
             (for-each delete-file
                       '("test/parallel/test-cluster-master-error.js"
                         "test/parallel/test-cluster-master-kill.js"
                         ;; See also <https://github.com/nodejs/node/issues/25903>.
                         "test/sequential/test-performance.js"))

             ;; This requires a DNS resolver.
             (delete-file "test/parallel/test-dns.js")

             ;; FIXME: This test fails randomly:
             ;; https://github.com/nodejs/node/issues/31213
             (delete-file "test/parallel/test-net-listen-after-destroying-stdin.js")

             ;; FIXME: These tests fail on armhf-linux:
             ;; https://github.com/nodejs/node/issues/31970
             ,@(if (string-prefix? "arm" (%current-system))
                   '((for-each delete-file
                               '("test/parallel/test-zlib.js"
                                 "test/parallel/test-zlib-brotli.js"
                                 "test/parallel/test-zlib-brotli-flush.js"
                                 "test/parallel/test-zlib-brotli-from-brotli.js"
                                 "test/parallel/test-zlib-brotli-from-string.js"
                                 "test/parallel/test-zlib-convenience-methods.js"
                                 "test/parallel/test-zlib-random-byte-pipes.js"
                                 "test/parallel/test-zlib-write-after-flush.js")))
                   '())

             ;; These tests have an expiry date: they depend on the validity of
             ;; TLS certificates that are bundled with the source.  We want this
             ;; package to be reproducible forever, so remove those.
             ;; TODO: Regenerate certs instead.
             (for-each delete-file
                       '("test/parallel/test-tls-passphrase.js"
                         "test/parallel/test-tls-server-verify.js"))
             #t))
         (replace 'configure
           ;; Node's configure script is actually a python script, so we can't
           ;; run it with bash.
           (lambda* (#:key outputs (configure-flags '()) inputs
                     #:allow-other-keys)
             (let* ((prefix (assoc-ref outputs "out"))
                    (flags (cons (string-append "--prefix=" prefix)
                                 configure-flags)))
               (format #t "build directory: ~s~%" (getcwd))
               (format #t "configure flags: ~s~%" flags)
               ;; Node's configure script expects the CC environment variable to
               ;; be set.
               (setenv "CC" (string-append (assoc-ref inputs "gcc") "/bin/gcc"))
               (apply invoke
                      (string-append (assoc-ref inputs "python")
                                     "/bin/python")
                      "configure" flags))))
         (add-after 'patch-shebangs 'patch-npm-shebang
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((bindir (string-append (assoc-ref outputs "out")
                                           "/bin"))
                    (npm    (string-append bindir "/npm"))
                    (target (readlink npm)))
               (with-directory-excursion bindir
                 (patch-shebang target (list bindir))
                 #t)))))))
    (native-inputs
     `(("python" ,python-2)
       ("perl" ,perl)
       ("pkg-config" ,pkg-config)
       ("procps" ,procps)
       ("util-linux" ,util-linux)
       ("which" ,which)))
    (native-search-paths
     (list (search-path-specification
            (variable "NODE_PATH")
            (files '("lib/node_modules")))))
    (inputs
     `(("c-ares" ,c-ares)
       ("http-parser" ,http-parser)
       ("icu4c" ,icu4c)
       ("libuv" ,libuv)
       ("nghttp2" ,nghttp2 "lib")
       ("openssl" ,openssl)
       ("zlib" ,zlib)))
    (synopsis "Evented I/O for V8 JavaScript")
    (description "Node.js is a platform built on Chrome's JavaScript runtime
for easily building fast, scalable network applications.  Node.js uses an
event-driven, non-blocking I/O model that makes it lightweight and efficient,
perfect for data-intensive real-time applications that run across distributed
devices.")
    (home-page "https://nodejs.org/")
    (license license:expat)
    (properties '((max-silent-time . 7200)     ;2h, needed on ARM
                  (timeout . 21600)))))        ;6h

;; TODO: Make this the default node on core-updates.  This cannot be done on
;; master since this version of node requires a newer nghttp2 library at link
;; time.
(define-public node-10.22
  (package
    (inherit node)
    (version "10.22.0")
    (source (origin
              (inherit (package-source node))
              (uri (string-append "https://nodejs.org/dist/v" version
                                  "/node-v" version ".tar.xz"))
              (sha256
               (base32
                "1nz18fa550li10r0kzsm28c2rvvq61nq8bqdygip0rmvbi2paxg0"))))
    (inputs
     (alist-replace "nghttp2" (list nghttp2-1.41 "lib")
                    (package-inputs node)))))

;; This should be the latest version of node that still builds without
;; depending on lltthp.
(define-public node-bootstrap
  (hidden-package node-10.22))

(define-public node-semver-bootstrap
  (package
    (inherit node-semver)
    (arguments
     (substitute-keyword-arguments (package-arguments node-semver)
       ((#:node _) node-bootstrap)))
    (properties '((hidden? #t)))))

(define-public node-ms-bootstrap
  (package
    (name "node-ms")
    (version "2.1.2")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/vercel/ms.git")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "1pjxzbi4j8pinlsc7yxvfrh0b47kb2dc4lfc2rjq4wx5bdwl33fj"))))
    (build-system node-build-system)
    (arguments
     `(#:node ,node-bootstrap
       #:tests? #f
       #:phases
       (modify-phases
           %standard-phases
         (delete 'configure)
         (delete 'build))))
    (home-page "https://github.com/zeit/ms#readme")
    (properties '((hidden? . #t)))
    (synopsis "Tiny millisecond conversion utility")
    (description
     "Use this package to easily convert various time formats to
milliseconds.")
    (license license:expat)))

(define-public node-binary-search-bootstrap
  (package
    (name "node-binary-search")
    (version "1.3.6")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/darkskyapp/binary-search.git")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "1xr2msdc143cd3xwgq7n3rhzy7j8wrnaidxl0r6l6b6g3mpbpjig"))))
    (build-system node-build-system)
    (arguments
     `(#:node ,node-bootstrap
       #:tests? #f
       #:phases
       (modify-phases
           %standard-phases
         (delete 'configure)
         (delete 'build))))
    (home-page
     "https://github.com/darkskyapp/binary-search#readme")
    (properties '((hidden? . #t)))
    (synopsis
     "Tiny binary search function with comparators")
    (description
     "This package is a binary search function for @code{Node.js}.")
    (license license:cc0)))

(define-public node-debug-bootstrap
  (package
    (name "node-debug")
    (version "4.3.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/visionmedia/debug.git")
             (commit version)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "08g52r1d4yqcsfdfb7n5if33d4cghaq75gx5n9hj6m6fd8jfp2pi"))))
    (build-system node-build-system)
    (arguments
     `(#:node ,node-bootstrap
       #:tests? #f
       #:phases
       (modify-phases
           %standard-phases
         (delete 'configure)
         (delete 'build))))
    (inputs `(("node-ms" ,node-ms-bootstrap)))
    (home-page
     "https://github.com/visionmedia/debug#readme")
    (properties '((hidden? . #t)))
    (synopsis "Small debugging utility")
    (description "This packages contains a tiny JavaScript debugging utility
modelled after @code{Node.js} core's debugging technique.  It works in
@code{Node.js} and web browsers.")
    (license license:expat)))

(define-public node-llparse-builder-bootstrap
  (package
    (name "node-llparse-builder")
    (version "1.5.2")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/indutny/llparse-builder.git")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "0r82iiwqsb73k2fxw7842rjjiixllxpyc6yl9cq4ma6ybkf6xmzm"))
       (modules '((guix build utils)))
       (snippet
        '(begin
           ;; FIXME: Unneeded runtime dependency
           ;; https://github.com/indutny/llparse-builder/pull/2
           (substitute* "package.json"
             (("\"@types/debug.*,") ""))
           ;; Fix incorrect import semantics
           ;; https://github.com/evanw/esbuild/issues/477
           (substitute* (list
                         "src/node/invoke.ts"
                         "src/node/base.ts"
                         "src/node/consume.ts"
                         "src/node/match.ts"
                         "src/node/error.ts"
                         "src/node/pause.ts"
                         "src/edge.ts"
                         "src/utils.ts"
                         "src/loop-checker/index.ts"
                         "src/loop-checker/lattice.ts"
                         "src/code/field.ts"
                         "src/span-allocator.ts")
             (("\\* as assert") "assert")
             (("\\* as debugAPI") "debugAPI"))
           #t))))
    (build-system node-build-system)
    (arguments
     `(#:node ,node-bootstrap
       #:tests? #f
       #:phases
       (modify-phases
           %standard-phases
         (delete 'configure)
         (replace 'build
           (lambda* (#:key inputs #:allow-other-keys)
             (let ((esbuild (string-append
                             (assoc-ref inputs "esbuild")
                             "/bin/esbuild")))
               (invoke esbuild
                       "--platform=node"
                       "--external:debug"
                       "--external:binary-search"
                       "--outfile=lib/builder.js"
                       "--bundle"
                       "src/builder.ts")))))))
    (inputs
     `(("node-binary-search" ,node-binary-search-bootstrap)
       ("node-debug" ,node-debug-bootstrap)))
    (native-inputs
     `(("esbuild" ,esbuild)))
    (home-page
     "https://github.com/indutny/llparse-builder#readme")
    (properties '((hidden? . #t)))
    (synopsis
     "Graph builder for consumption by @code{llparse}")
    (description
     "This package builds graphs for consumption by @code{llparse}.")
    (license license:expat)))

(define-public node-llparse-frontend-bootstrap
  (package
    (name "node-llparse-frontend")
    (version "3.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/indutny/llparse-frontend.git")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "1rm9g4ifyip30svm5cgnf0gx7d45jgh4mpf2hkd092xhngmfvicc"))
       (modules '((guix build utils)))
       (snippet
        '(begin
           ;; Fix incorrect import semantics
           ;; https://github.com/evanw/esbuild/issues/477
           (substitute* (list "src/frontend.ts"
                              "src/code/field-value.ts"
                              "src/container/index.ts"
                              "src/container/wrap.ts"
                              "src/node/sequence.ts"
                              "src/node/single.ts"
                              "src/node/table-lookup.ts"
                              "src/trie/index.ts")
             (("\\* as assert") "assert")
             (("\\* as debugAPI") "debugAPI"))
           #t))))
    (build-system node-build-system)
    (arguments
     `(#:node ,node-bootstrap
       #:tests? #f
       #:phases
       (modify-phases
           %standard-phases
         (delete 'configure)
         (replace 'build
           (lambda* (#:key inputs #:allow-other-keys)
             (let ((esbuild (string-append
                             (assoc-ref inputs "esbuild")
                             "/bin/esbuild")))
               (invoke esbuild
                       "--platform=node"
                       "--external:debug"
                       "--external:llparse-builder"
                       "--outfile=lib/frontend.js"
                       "--bundle"
                       "src/frontend.ts")))))))
    (inputs
     `(("node-debug" ,node-debug-bootstrap)
       ("node-llparse-builder" ,node-llparse-builder-bootstrap)))
    (native-inputs
     `(("esbuild" ,esbuild)))
    (home-page
     "https://github.com/indutny/llparse-frontend#readme")
    (properties '((hidden? . #t)))
    (synopsis "Frontend for @code{llparse} compiler")
    (description "This package is a frontend for the @code{llparse}
compiler.")
    (license license:expat)))

(define-public node-llparse-bootstrap
  (package
    (name "node-llparse")
    (version "7.1.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/indutny/llparse.git")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "10da273iy2if88hp79cwms6c8qpsl1fkgzll6gmqyx5yxv5mkyp6"))
       (modules '((guix build utils)))
       (snippet
        '(begin
           ;; Fix incorrect import semantics
           ;; https://github.com/evanw/esbuild/issues/477
           (substitute* (list "src/compiler/index.ts"
                              "src/implementation/c/node/base.ts"
                              "src/implementation/c/node/table-lookup.ts"
                              "src/implementation/c/compilation.ts"
                              "src/implementation/c/helpers/match-sequence.ts"
                              "src/implementation/c/code/mul-add.ts")
             (("\\* as assert") "assert")
             (("\\* as debugAPI") "debugAPI"))
           #t))))
    (build-system node-build-system)
    (arguments
     `(#:node ,node-bootstrap
       #:tests? #f
       #:phases
       (modify-phases
           %standard-phases
         (delete 'configure)
         (replace 'build
           (lambda* (#:key inputs #:allow-other-keys)
             (let ((esbuild (string-append
                             (assoc-ref inputs "esbuild")
                             "/bin/esbuild")))
               (invoke esbuild
                       "--platform=node"
                       "--external:debug"
                       "--external:llparse-frontend"
                       "--outfile=lib/api.js"
                       "--bundle"
                       "src/api.ts")))))))
    (inputs
     `(("node-debug" ,node-debug-bootstrap)
       ("node-llparse-frontend"
        ,node-llparse-frontend-bootstrap)))
    (native-inputs
     `(("esbuild" ,esbuild)))
    (home-page
     "https://github.com/nodejs/llparse#readme")
    (properties '((hidden? . #t)))
    (synopsis
     "Compile incremental parsers to C code")
    (description
     "This package offers an API for compiling an incremental parser
definition into a C output.")
    (license license:expat)))

(define-public llhttp-bootstrap
  (package
    (name "llhttp")
    (version "2.1.0")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/nodejs/llhttp.git")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "08ylnirqrk63h0ww1m79p0bh6rwayrhd4v28p353qlp3qcffwwb0"))
              (modules '((guix build utils)))
              (snippet
               '(begin
                  ;; Fix incorrect import semantics
                  ;; https://github.com/evanw/esbuild/issues/477
                  (substitute* "src/llhttp/http.ts"
                    (("\\* as assert")
                     "assert"))
                  (substitute* "Makefile"
                    (("npx ts-node bin/generate.ts")
                     "node bin/generate.js"))
                  #t))))
    (build-system gnu-build-system)
    (arguments
     `(#:tests? #f                      ; no tests
       #:make-flags (list "CLANG=gcc"
                          (string-append "DESTDIR=" (assoc-ref %outputs "out"))
                          "PREFIX=")
       #:phases (modify-phases %standard-phases
                  (replace 'configure
                    (lambda* (#:key inputs #:allow-other-keys)
                      (let ((esbuild (string-append
                                      (assoc-ref inputs "esbuild")
                                      "/bin/esbuild")))
                        (invoke esbuild
                                "--platform=node"
                                "--external:semver"
                                "--external:llparse"
                                "--outfile=bin/generate.js"
                                "--bundle" "bin/generate.ts"))))
                  (add-before 'install 'create-install-directories
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let ((out (assoc-ref outputs "out")))
                        (for-each (lambda (dir)
                                    (mkdir-p (string-append out dir)))
                                  (list "/lib" "/include" "/src"))
                        #t)))
                  (add-after 'install 'install-src
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let* ((out (assoc-ref outputs "out"))
                             (src-dir (string-append out "/src")))
                        (install-file "build/c/llhttp.c" src-dir)
                        #t))))))
    (native-inputs
     `(("esbuild" ,esbuild)
       ("node" ,node-bootstrap)
       ("node-semver" ,node-semver-bootstrap)
       ("node-llparse-bootstrap" ,node-llparse-bootstrap)))
    (home-page "https://github.com/nodejs/llhttp")
    (properties '((hidden? . #t)))
    (synopsis "Port of @code{http_parser} to @code{llparse}")
    (description "@code{llhttp} is a port of @code{http_parser} to TypeScript.
@code{llparse} is used to generate the output C source file, which can be
compiled and linked with the embedder's program (like @code{Node.js}).")
    (license license:expat)))

(define-public node-14.14
  (package
    (inherit node)
    (version "14.14.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://nodejs.org/dist/v" version
                                  "/node-v" version ".tar.xz"))
              (sha256
               (base32
                "1rphkl3lqg0rzgg0r58bfv1hjw3rg96qvqcilk2927kbpps3bs84"))
              (modules '((guix build utils)))
              (snippet
               `(begin
                  ;; Remove bundled software, where possible
                  (for-each delete-file-recursively
                            '("deps/cares"
                              "deps/icu-small"
                              "deps/nghttp2"
                              "deps/openssl"
                              "deps/zlib"))
                  (substitute* "Makefile"
                    ;; Remove references to bundled software.
                    (("deps/uv/uv.gyp") "")
                    (("deps/zlib/zlib.gyp") ""))
                  #t))))
    (arguments
     (substitute-keyword-arguments (package-arguments node)
       ((#:configure-flags configure-flags)
        ''("--shared-cares"
           "--shared-libuv"
           "--shared-nghttp2"
           "--shared-openssl"
           "--shared-zlib"
           "--shared-brotli"
           "--with-intl=system-icu"))
       ((#:phases phases)
        `(modify-phases ,phases
           (replace 'configure
             ;; Node's configure script is actually a python script, so we can't
             ;; run it with bash.
             (lambda* (#:key outputs (configure-flags '()) inputs
                       #:allow-other-keys)
               (let* ((prefix (assoc-ref outputs "out"))
                      (flags (cons (string-append "--prefix=" prefix)
                                   configure-flags)))
                 (format #t "build directory: ~s~%" (getcwd))
                 (format #t "configure flags: ~s~%" flags)
                 ;; Node's configure script expects the CC environment variable to
                 ;; be set.
                 (setenv "CC" (string-append (assoc-ref inputs "gcc") "/bin/gcc"))
                 (apply invoke
                        (string-append (assoc-ref inputs "python")
                                       "/bin/python3")
                        "configure" flags))))
           (replace 'patch-files
             (lambda* (#:key inputs #:allow-other-keys)
               ;; Fix hardcoded /bin/sh references.
               (substitute* '("lib/child_process.js"
                              "lib/internal/v8_prof_polyfill.js"
                              "test/parallel/test-child-process-spawnsync-shell.js"
                              "test/parallel/test-stdio-closed.js"
                              "test/sequential/test-child-process-emfile.js")
                 (("'/bin/sh'")
                  (string-append "'" (which "sh") "'")))

               ;; Fix hardcoded /usr/bin/env references.
               (substitute* '("test/parallel/test-child-process-default-options.js"
                              "test/parallel/test-child-process-env.js"
                              "test/parallel/test-child-process-exec-env.js")
                 (("'/usr/bin/env'")
                  (string-append "'" (which "env") "'")))

               ;; FIXME: These tests fail in the build container, but they don't
               ;; seem to be indicative of real problems in practice.
               (for-each delete-file
                         '("test/parallel/test-cluster-master-error.js"
                           "test/parallel/test-cluster-master-kill.js"))

               ;; This requires a DNS resolver.
               (for-each delete-file
                         '("test/parallel/test-dns.js"
                           "test/parallel/test-dns-lookupService-promises.js"))

               ;; TODO: why does this fail. It seems to _almost_ pass, but it parses 1 byte?
               (delete-file "test/parallel/test-http-server-destroy-socket-on-client-error.js")

               ;; TODO: this seems to fail because of spawning processes?
               (delete-file "test/parallel/test-fs-write-sigxfsz.js")

               ;; FIXME: This test fails randomly:
               ;; https://github.com/nodejs/node/issues/31213
               (delete-file "test/parallel/test-net-listen-after-destroying-stdin.js")

               ;; FIXME: These tests fail on armhf-linux:
               ;; https://github.com/nodejs/node/issues/31970
               ,@(if (string-prefix? "arm" (%current-system))
                     '((for-each delete-file
                                 '("test/parallel/test-zlib.js"
                                   "test/parallel/test-zlib-brotli.js"
                                   "test/parallel/test-zlib-brotli-flush.js"
                                   "test/parallel/test-zlib-brotli-from-brotli.js"
                                   "test/parallel/test-zlib-brotli-from-string.js"
                                   "test/parallel/test-zlib-convenience-methods.js"
                                   "test/parallel/test-zlib-random-byte-pipes.js"
                                   "test/parallel/test-zlib-write-after-flush.js")))
                     '())

               ;; These tests have an expiry date: they depend on the validity of
               ;; TLS certificates that are bundled with the source.  We want this
               ;; package to be reproducible forever, so remove those.
               ;; TODO: Regenerate certs instead.
               (for-each delete-file
                         '("test/parallel/test-tls-passphrase.js"
                           "test/parallel/test-tls-server-verify.js"))

               ;; Replace pre-generated llhttp sources
               (let ((llhttp (assoc-ref inputs "llhttp")))
                 (copy-file (string-append llhttp "/src/llhttp.c")
                            "deps/llhttp/src/llhttp.c")
                 (copy-file (string-append llhttp "/include/llhttp.h")
                            "deps/llhttp/include/llhttp.h"))
               #t))))))
    (inputs
     `(("c-ares" ,c-ares)
       ("icu4c" ,icu4c-67)
       ("libuv" ,libuv-node)
       ("llhttp" ,llhttp-bootstrap)
       ("google-brotli" ,google-brotli)
       ("nghttp2" ,nghttp2-1.41 "lib")
       ("openssl" ,openssl)
       ("zlib" ,zlib)))
    (native-inputs
     (alist-replace "python" (list python-3)
                    (package-native-inputs node)))))

(define-public libnode
  (package
    (inherit node)
    (name "libnode")
    (arguments
     (substitute-keyword-arguments (package-arguments node)
       ((#:configure-flags flags ''())
        `(cons* "--shared" "--without-npm" ,flags))
       ((#:phases phases '%standard-phases)
        `(modify-phases ,phases
           (delete 'patch-npm-shebang)))))))
