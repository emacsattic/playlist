;;; playlist.el --- A music file playlist

;; Copyright (C) 2002  Shawn Betts

;; Author: Shawn Betts <sabetts@vcn.bc.ca>
;; Keywords: multimedia

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; Maintain a playlist and play songs.
;; to run:
;;
;; M-x playlist RET
;;

;;; Code:

(defvar playlist-default-program "mpg321"
  "playlist uses this program when no match could be found in playlist-programs")

(defvar playlist-programs '(("ogg" . "ogg123")
                            ("mp3" . "mpg321"))
  "A list of file extension and program dotted pairs to use to play each extension")

(defvar playlist-process nil)

(defvar playlist-overlay nil)

(defgroup playlist nil
  "A major mode for playing songs and maintaining play lists."
  :group 'multimedia)

(defgroup playlist-faces nil
  "Customizations for faces used by playlist."
  :group 'playlist)

(defface playlist-play-face
  `((t (:foreground "Orange")))
  "The face used to notify the user of which song is being played."
  :group 'playlist-faces)

(defvar playlist-mode-hook nil
  "A hook called after entering the playlist major mode")

(defvar playlist-mode-map nil
  "playlist major mode map")

(if playlist-mode-map
    ()
  (setq playlist-mode-map (make-sparse-keymap))
  (define-key playlist-mode-map "\C-ca" 'playlist-add-song)
  (define-key playlist-mode-map "\C-cp" 'playlist-play-song)
  (define-key playlist-mode-map "\C-c " 'playlist-pause-song)
  (define-key playlist-mode-map "\C-cn" 'playlist-play-next-song))

(defun playlist-mode ()
  "Major mode for playing songs.

\\{playlist-mode-map}"
  (interactive)
  (kill-all-local-variables)
  (use-local-map playlist-mode-map)
  (setq playlist-overlay (make-overlay 0 0))
  (overlay-put playlist-overlay 'face 'playlist-play-face)
  (setq mode-name "Playlist")
  (setq major-mode 'playlist-mode)
  (run-hooks 'playlist-mode-hook))

(defun playlist ()
  (interactive)
  (switch-to-buffer (get-buffer-create "*playlist*"))
  (let ((inhibit-read-only t))
      (erase-buffer))
  (playlist-mode))

(defun playlist-add-song (file)
  (interactive "fFile: ")
  (with-current-buffer (overlay-buffer playlist-overlay)
    (save-excursion
      (goto-char (point-max))
      (insert file "\n"))))

(defun playlist-play-song ()
  "Plays the song at point"
  (interactive)
  (playlist-stop-song)
  (save-excursion
    (let (start)
      (playlist-move-overlay)
      (playlist-play (expand-file-name (buffer-substring start (point)))))))

(defun playlist-play (file)
  (let ((program (cdr (assoc (file-name-extension file) playlist-programs))))
    (unless program
      (setq program playlist-default-program))
    (setq playlist-process (start-process "playlist" nil program file))
    (set-process-sentinel playlist-process 'playlist-process-sentinel)))

(defun playlist-stop-song ()
  "Stop playing the current song"
  (interactive)
  (when (and (processp playlist-process)
             (member (process-status playlist-process) '(run stop)))
    (kill-process playlist-process)))

(defun playlist-pause-song ()
  "Pause playing the current song. If it is already paused, then
resume."
  (interactive)
  (when (processp playlist-process)
    (if (eq (process-status playlist-process)
            'stop)
        (playlist-resume-song)
      (stop-process playlist-process))))

(defun playlist-resume-song ()
  "Resume a paused song"
  (interactive)
  (when (processp playlist-process)
    (continue-process playlist-process)))

(defun playlist-process-sentinel (proc signal)
  (when (string-equal signal "finished\n")
    (playlist-play-next-song)))

(defun playlist-move-overlay ()
  "Expand the overlay to the beginning and end of the line."
  (beginning-of-line)
  (setq start (point))
  (end-of-line)
  (move-overlay playlist-overlay start (point)))  

(defun playlist-play-next-song ()
  (interactive)
  (playlist-stop-song)
  (with-current-buffer (overlay-buffer playlist-overlay)
    (let (old)
      (save-excursion
        (goto-char (overlay-end playlist-overlay))
        (setq old (point))
        (forward-line)
        (unless (= old (point))
          (playlist-move-overlay)
          (playlist-play (expand-file-name (buffer-substring start (point)))))))))

(defun playlist-add-dired-marked-files ()
  "Add the files marked in a dired buffer"
  (interactive)
  (mapcar 'playlist-add-song (dired-get-marked-files)))

(defun playlist-add-dired-file ()
  "Add the file at point in a dired buffer to the playlist"
  (interactive)
  (playlist-add-song (dired-get-filename)))

(provide 'playlist)
;;; playlist.el ends here
