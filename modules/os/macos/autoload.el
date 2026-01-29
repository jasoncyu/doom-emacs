;;; os/macos/autoload.el -*- lexical-binding: t; -*-

;;;###autoload
(defun +macos-defaults (action &rest args)
  (apply #'doom-call-process "defaults" action args))

;;;###autoload
(defun +macos-open-with (&optional app-name path)
  "Send PATH to APP-NAME on OSX."
  (interactive)
  (let* ((path (expand-file-name
                (replace-regexp-in-string
                 "'" "\\'"
                 (or path (if (derived-mode-p 'dired-mode)
                              (dired-get-file-for-visit)
                            (buffer-file-name)))
                 nil t)))
         (args (cons "open"
                     (append (if app-name (list "-a" app-name))
                             (list path)))))
    (message "Running: %S" args)
    (apply #'doom-call-process args)))

(defmacro +macos--open-with (id &optional app dir)
  `(defun ,(intern (format "+macos/%s" id)) ()
     (interactive)
     (+macos-open-with ,app ,dir)))

(defmacro +macos--open-with-iterm (id &optional dir newwindow?)
  `(defun ,(intern (format "+macos/%s" id)) ()
     (interactive)
     (letf! ((defun read-newwindows ()
               (cdr (+macos-defaults
                     "read" "com.googlecode.iterm2" "OpenFileInNewWindows")))
             (defun write-newwindows (bool)
               (+macos-defaults
                "write" "com.googlecode.iterm2" "OpenFileInNewWindows"
                "-bool" (if bool "true" "false"))))
       (let ((newwindow?
              (if ,newwindow? (not (equal (read-newwindows) "1")))))
         (when newwindow?
           (write-newwindows t))
         (unwind-protect (+macos-open-with "iTerm" ,dir)
           (when newwindow?
             (write-newwindows nil)))))))

;;;###autoload (autoload '+macos/open-in-default-program "os/macos/autoload" nil t)
(+macos--open-with open-in-default-program)

;;;###autoload (autoload '+macos/reveal-in-finder "os/macos/autoload" nil t)
(+macos--open-with reveal-in-finder "Finder" default-directory)

;;;###autoload (autoload '+macos/reveal-project-in-finder "os/macos/autoload" nil t)
(+macos--open-with reveal-project-in-finder "Finder"
                   (or (doom-project-root) default-directory))

;;;###autoload (autoload '+macos/send-to-transmit "os/macos/autoload" nil t)
(+macos--open-with send-to-transmit "Transmit")

;;;###autoload (autoload '+macos/send-cwd-to-transmit "os/macos/autoload" nil t)
(+macos--open-with send-cwd-to-transmit "Transmit" default-directory)

;;;###autoload (autoload '+macos/send-to-launchbar "os/macos/autoload" nil t)
(+macos--open-with send-to-launchbar "LaunchBar")

;;;###autoload (autoload '+macos/send-project-to-launchbar "os/macos/autoload" nil t)
(+macos--open-with send-project-to-launchbar "LaunchBar"
                   (or (doom-project-root) default-directory))

;;;###autoload (autoload '+macos/open-in-iterm "os/macos/autoload" nil t)
(+macos--open-with-iterm open-in-iterm default-directory)

;;;###autoload (autoload '+macos/open-in-iterm-new-window "os/macos/autoload" nil t)
(+macos--open-with-iterm open-in-iterm-new-window default-directory t)

;;;###autoload (autoload '+macos/open-in-kitty "os/macos/autoload" nil t)
(defun +macos/open-in-kitty ()
  (interactive)
  ;; Open tab
  (shell-command
   (format
    "kitty @ launch --to=%s --type tab --cwd %s"
    "unix:/tmp/mykitty"
    (shell-quote-argument
     default-directory)))
  ;; (shell-command (format "kitty @ launch --type tab --cwd %s" (shell-quote-argument default-directory)))
  ;; Focus Kitty
  (shell-command "open -a Kitty"))

;;;###autoload
(defun +macos/open-current-file-in-app ()
  "Open the current buffer's file in a chosen application, with Consult autocompletion.
Strips .app extension from displayed and executed app names.
Prints the shell command for debugging.
More robustly finds application paths."
  (interactive)
  (let ((current-file (buffer-file-name)))
    (when current-file
      (let* ((apps-dirs '("/Applications/" "/System/Applications/"))
             ;; Collect all .app files and derive their base names
             (all-app-files (cl-loop for app-dir in apps-dirs
                                     append (directory-files app-dir nil "\\.app$")))
             (app-names-without-ext (mapcar (lambda (app-file)
                                              (s-chop-suffix ".app" app-file)
                                              )
                                            all-app-files))
             (selected-app-base-name))

        (setq selected-app-base-name
              (completing-read "Open with application: "
                               app-names-without-ext
                               nil t nil nil " "))

        (when (and selected-app-base-name (not (string-empty-p selected-app-base-name)))
          (shell-command
           (format "open -a '%s' '%s'"
                   ;; Use the base name for 'open -a'
                   (replace-regexp-in-string "'" "'\\''" selected-app-base-name)
                   (replace-regexp-in-string "'" "'\\''" current-file))))))))

