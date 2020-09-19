;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2018 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2018 Tobias Geerinckx-Rice <me@tobias.gr>
;;; Copyright © 2019 Ricardo Wurmus <rekado@elephly.net>
;;; Copyright © 2020 Andreas Enge <andreas@enge.fr>
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

(define-module (gnu packages printers)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system perl)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages)
  #:use-module (gnu packages boost)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages cups)
  #:use-module (gnu packages ghostscript)
  #:use-module (gnu packages libusb)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages qt)
  #:use-module (gnu packages web)
  #:use-module (gnu packages wxwidgets))

;; This is a module for packages related to printer-like devices, but not
;; related to CUPS.

(define-public robocut
  (package
    (name "robocut")
    (version "1.0.11")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/Timmmm/robocut")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0dp9cssyik63yvkk35s51v94a873x751iqg93qzd8dpqkmz5z8gn"))))
    (build-system gnu-build-system)
    (arguments
     '(#:phases (modify-phases %standard-phases
                  (replace 'configure
                    (lambda* (#:key outputs #:allow-other-keys)
                      (let ((out (assoc-ref outputs "out")))
                        (substitute* "Robocut.pro"
                          (("/usr/")
                           (string-append out "/")))

                        (invoke "qmake"
                                (string-append "PREFIX=" out))
                        #t))))))
    (inputs
     `(("libusb" ,libusb)
       ("qt" ,qtbase)
       ("qtsvg" ,qtsvg)))
    (native-inputs
     `(("pkg-config" ,pkg-config)
       ("qmake" ,qtbase)))
    (synopsis "Graphical program to drive plotting cutters")
    (description
     "Robocut is a simple graphical program that allows you to cut graphics
with Graphtec and Sihouette plotting cutters using an SVG file as its input.")
    (home-page "http://robocut.org")
    (license license:gpl3+)))

(define-public brlaser
  (package
    (name "brlaser")
    (version "6")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/pdewacht/brlaser")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32
                "1995s69ksq1fz0vb34v0ndiqncrinbrlpmp70rkl6az7kag99s80"))))
    (build-system cmake-build-system)
    (arguments
     `(#:configure-flags
       (list (string-append "-DCUPS_DATA_DIR="
                            (assoc-ref %outputs "out")
                            "/share/cups")
             (string-append "-DCUPS_SERVER_BIN="
                            (assoc-ref %outputs "out")
                            "/lib/cups"))))
    (inputs
     `(("ghostscript" ,ghostscript)
       ("cups" ,cups)
       ("zlib" ,zlib)))
    (home-page "https://github.com/pdewacht/brlaser")
    (synopsis "Brother laser printer driver")
    (description "Brlaser is a CUPS driver for Brother laser printers.  This
driver is known to work with these printers:

@enumerate
@item Brother DCP-1510 series
@item Brother DCP-1600 series
@item Brother DCP-7030
@item Brother DCP-7040
@item Brother DCP-7055
@item Brother DCP-7055W
@item Brother DCP-7060D
@item Brother DCP-7065DN
@item Brother DCP-7080
@item Brother DCP-L2500D series
@item Brother DCP-L2520D series
@item Brother DCP-L2540DW series
@item Brother HL-1110 series
@item Brother HL-1200 series
@item Brother HL-2030 series
@item Brother HL-2140 series
@item Brother HL-2220 series
@item Brother HL-2270DW series
@item Brother HL-5030 series
@item Brother HL-L2300D series
@item Brother HL-L2320D series
@item Brother HL-L2340D series
@item Brother HL-L2360D series
@item Brother MFC-1910W
@item Brother MFC-7240
@item Brother MFC-7360N
@item Brother MFC-7365DN
@item Brother MFC-7840W
@item Brother MFC-L2710DW series
@item Lenovo M7605D
@end enumerate")
    (license license:gpl2+)))

(define-public slic3r
  (package
    (name "slic3r")
    (version "1.3.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/slic3r/Slic3r.git")
             (commit version)))
       (patches (search-patches "slic3r-gcc-8.patch"))
       (sha256
        (base32 "1pg4jxzb7f58ls5s8mygza8kqdap2c50kwlsdkf28bz1xi611zbi"))))
    (build-system perl-build-system)
    (arguments
     '(#:tests? #f ; no tests in package
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'no-local-lib
           (lambda _
             ;; Drop loading of the local::lib module.
             (substitute* (find-files "t" "\\.t$")
               (("use local::lib.*$") ""))
             ;; While we are at it, correct a buggy path in a source file.
             (substitute* "xs/src/libslic3r/GCodeSender.cpp"
               (("\"/usr/include/asm-generic/ioctls.h\"")
                 "<asm-generic/ioctls.h>"))
             #t))
         (add-before 'configure 'set-env
           (lambda _
             (setenv "SLIC3R_NO_AUTO" "1") ; to avoid the use of cpanm
             (setenv "PERL5LIB" (string-append (getcwd) "/xs/blib/arch:"
                                               (getcwd) "/xs/blib/lib:"
                                               (getenv "PERL5LIB")))
             #t))
         (add-before 'configure 'build-xs
           (lambda _
             (with-directory-excursion "xs"
               (system* "perl" "Build.PL")
               (system* "perl" "Build"))
             #t))
         (add-after 'configure 'build-gui
           (lambda _
             (system* "perl" "Build.PL" "--gui")
             #t))
         (delete 'build)))) ; everything is done elsewhere
    (native-inputs
     `(("perl-class-accessor" ,perl-class-accessor)
       ("perl-devel-checklib" ,perl-devel-checklib)
       ("perl-encode-locale" ,perl-encode-locale)
       ("perl-extutils-cppguess" ,perl-extutils-cppguess)
       ("perl-extutils-typemaps-default" ,perl-extutils-typemaps-default)
       ("perl-io-stringy" ,perl-io-stringy)
       ("perl-module-build-withxspp" ,perl-module-build-withxspp)
       ("perl-moo" ,perl-moo)
       ("perl-scalar-list-utils" ,perl-scalar-list-utils)))
    (inputs
     `(("boost" ,boost)
       ("wxwidgets-gtk2" ,wxwidgets-gtk2)))
    (home-page "https://slic3r.org/")
    (synopsis "3D printing toolbox")
    (description "Slic3r is a tool to convert a 3D model into printing
instructions for a 3D printer.  It cuts the model into horizontal slices
(layers), generates toolpaths to fill them and calculates the amount of
material to be extruded.")
    (license license:agpl3+)))
