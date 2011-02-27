;;; -*- Mode: lisp -*-
; ctags.l
;
; ctags.exe ���g�p���ă^�O�W�����v���s���@�\���
; ctags ���{��Ή��� http://hp.vector.co.jp/authors/VA025040/ctags/
;
; by MATSUOKA Hiroshi <matsuoka@fun.sci.fukuoka-u.ac.jp>
;
; .xyzzy sample
; (load-library "ctags")
; ; ctags.exe �ւ̃p�X
; (setf *ctags-command-path* (merge-pathnames "etc/ctags.exe" (si:system-root)))
; ; ctags.exe �ւ̂��̑��̃I�v�V����
; ;(setf *ctags-command-option* "")
; (global-set-key #\M-. 'ctags-jump-tag)
; (global-set-key #\M-\, 'ctags-back-tag-jump)
; (global-set-key #\M-/ 'ctags-make-tags-file)
; ;(global-set-key #\M-/ 'ctags-make-tags-file-recursive)
;
; [2005/09/28] matsuoka@fun.sci.fukuoka-u.ac.jp
; �쐬�B
; [2007/12/02] matsuoka@fun.sci.fukuoka-u.ac.jp
; �n�b�V���x�[�X����B���o�b�t�@�ł̌����ɐ؂�ւ�
; [2007/12/08] matsuoka@fun.sci.fukuoka-u.ac.jp
; NANRI ����̎w�E���󂯂� tags �� / ���N�H�[�g����Ă�̂��͂���
;
(provide "ctags")
(in-package "editor")
(export '(*ctags-command-path*
					ctags-make-tags-file
					ctags-make-tags-file-recursive
					ctags-jump-tag
					ctags-back-tag-jump
          ctags-select-stack
          *ctags-version*
					))
(defvar *ctags-version* "20071208")
; ctags.exe �̏ꏊ�ƃI�v�V����
(defvar *ctags-command-path* nil)
(defvar *ctags-command-option* "")
; tags ��ǂݍ��ރo�b�t�@���̃v���t�B�N�X
(defvar *ctags-tags-buffer-prefix* " *Ctags ")
; tags ��ǂݍ��񂾃o�b�t�@�̈ꗗ
(defvar *ctags-tags-buffer-list* nil)
; �o�b�t�@���[�J���ȃ^�O�X�^�b�N
(defvar-local *ctags-tags-stack* nil)
; tags �Ƃ��Ďg�p����o�b�t�@��
(defvar-local *ctags-tags-buffer-name* nil)

; tags �t�@�C���̍쐬(�T�u�f�B���N�g������)
(defun ctags-make-tags-file (dir)
	(interactive "DMakeTagsTo: "
		:default01 (if (get-buffer-file-name)
									 (pathname-directory (get-buffer-file-name))
								 ""))
	(ctags-execute-command dir))

; tags �t�@�C���̍쐬(�T�u�f�B���N�g���܂�)
(defun ctags-make-tags-file-recursive (dir)
	(interactive "DMakeTagsTo: "
		:default01 (if (get-buffer-file-name)
									 (pathname-directory (get-buffer-file-name))
								 ""))
	(ctags-execute-command dir t))

; ctags �̎��s
(defun ctags-execute-command (dir &optional recursive)
	(if (and dir
					 (call-process
						(format nil "~A ~A ~A"
										*ctags-command-path*
										(if recursive "-R" "*")
										*ctags-command-option*)
						:exec-directory dir
						:wait t
						:show :minimize)
					 (ctags-make-tags-map dir))
			(message "ctags: created tags file")
		(message "ctags: cannot create tags file")))


; tags �t�@�C���̓ǂݍ���(�f�B���N�g���w��)
(defun ctags-make-tags-map (dir)
  (interactive "DReadTagsFrom: "
    :default01 (if (get-buffer-file-name)
                   (pathname-directory (get-buffer-file-name))
                 ""))
  (cond
   ((and
     (null *ctags-tags-buffer-name*)
     (not (file-exist-p (merge-pathnames "tags" dir))))
    (when (yes-or-no-p "tags �t�@�C��������܂���B�쐬���܂���?")
      (call-interactively 'ctags-make-tags-file-recursive)))
   ((or (null *ctags-tags-buffer-name*)
        (yes-or-no-p "���� tags ��ǂݍ���ł܂��B�㏑�����܂���?"))
    (progn
      (let* ((file-path (merge-pathnames "tags" dir))
             (buffer (concatenate 'string *ctags-tags-buffer-prefix* file-path)))
        (setf *ctags-tags-buffer-name* buffer)
        (get-buffer-create buffer)
        (erase-buffer buffer)
        (save-excursion
          (switch-to-buffer buffer)
          (push buffer *ctags-tags-buffer-list*)
          (make-local-variable 'ctags-tags-file-dir-path)
          (setf ctags-tags-file-dir-path dir)
          (make-local-variable 'need-not-save)
          (setf need-not-save t)
          (make-local-variable 'auto-save)
          (setf auto-save nil)
          (insert-file file-path)
          (goto-char 0)
          (do ((line (ctags-get-current-line)
                     (ctags-get-current-line)))
              ((not (string-match "^!_TAG_" (car line))))
            (delete-region (cadr line) (cddr line))
            (delete-char))))))))

; �o�b�t�@�̌��ݍs�ƍs���s���̃|�C���g��Ԃ�
(defun ctags-get-current-line ()
  (let ((end (progn (goto-eol) (point)))
        (begin (progn (goto-bol) (point))))
    (cons (buffer-substring begin end) (cons begin end))))

; tags ��ǂݍ��񂾃o�b�t�@����ړI�̎��ʎq�ƈ�v���郊�X�g��ԋp
(defun ctags-search-tag (word)
  (save-excursion
    (switch-to-buffer *ctags-tags-buffer-name*)
    (goto-char 0)
    (let ((tags nil)
          (regexp (compile-regexp (format nil "^~A\t\\([^\t]+\\)\t\\(.+\\);\"" (regexp-quote word)))))
      (while (scan-buffer regexp :no-dup t :regexp t)
        (push (cons (merge-pathnames (match-string 1) ctags-tags-file-dir-path) (match-string 2)) tags))
      tags)))

; �^�O�W�����v
(defun ctags-jump-tag ()
  (interactive)
  (when (not *ctags-tags-buffer-name*)
    (call-interactively 'ctags-make-tags-map))
  (when *ctags-tags-buffer-name*
    (let* ((word (ctags-get-current-identifier))
           (tags (ctags-search-tag word)))
      (case (length tags)
        (0 (message "unknown identifier ~A" word))
        (1 (ctags-goto-tag (car tags)))
        (t (ctags-select-next-tag tags))))))

; �o�b�N�^�O�W�����v
(defun ctags-back-tag-jump ()
	(interactive)
	(when *ctags-tags-buffer-name*
		(if (null *ctags-tags-stack*)
        (message "no stack for back tag jump")
      (ctags-goto-tag1 (pop *ctags-tags-stack*)))))

; �C�ӂ̃^�O�Ɉړ�(�X�^�b�N��ς�)
(defun ctags-goto-tag (tag)
  (ctags-push-current-marker)
  (ctags-goto-tag1 tag))

; �C�ӂ̃^�O�Ɉړ�
(defun ctags-goto-tag1 (tag)
  (let ((file (car tag))
        (marker (cdr tag))
        (buffer *ctags-tags-buffer-name*)
        (tags-stack *ctags-tags-stack*))
    (find-file file)
    (goto-char 0)
    (cond
     ((integerp marker)
      (goto-char marker))
     ((string-match "^[0-9]+$" marker)
      (goto-line (parse-integer marker)))
     (t
      (cond
       ((string-match "^/\\^\\(.+\\)\\$/$" marker)
        (re-search-forward
         (regexp-quote (substitute-string (match-string 1) "\\\\/" "/"))))
       (t
        (re-search-forward marker)))))
    (setf *ctags-tags-buffer-name* buffer)
    (setf *ctags-tags-stack* tags-stack)))

; �����̃^�O���玟�̃W�����v������肷��
(defun ctags-select-next-tag (tags)
  (ctags-goto-tag (ctags-select-tag tags)))

; ���݂̃X�^�b�N�̒���I�����Ė߂�
(defun ctags-select-stack ()
  (interactive)
  (if (not *ctags-tags-stack*)
      (msgbox "�X�^�b�N������܂���")
    (let ((tag (ctags-select-tag *ctags-tags-stack*)))
      (when tag
        (setf *ctags-tags-stack*
              (cdr (member tag *ctags-tags-stack* :test 'eq)))
        (ctags-goto-tag1 tag)))))

; �����̃^�O���~�j�o�b�t�@�ŃW�����v���I������Btag ��ԋp
(defun ctags-select-tag (tags)
  (let ((l nil) (i 0))
    (save-excursion
      (switch-to-buffer *ctags-tags-buffer-name*)
      (dolist (x tags)
        (push (format nil "~2A:\"$~A\": ~A"
                      i
                      (substring (car x) (+ 1 (length ctags-tags-file-dir-path)))
                      (if (stringp (cdr x)) (string-trim " 	/^$" (cdr x)) (cdr x)))
              l)
        (setf i (+ i 1))))
    (let ((selected
           (completing-read
            "Select Tag: " l :must-match t :default (if (= (length l) 1) (car l) nil) :history nil)))
      (nth (parse-integer (string-trim " " (car (split-string selected ":")))) tags))))


; ���݈ʒu�����[�J���̃X�^�b�N�ɐς�
(defun ctags-push-current-marker ()
  (push (cons (get-buffer-file-name) (point))
        *ctags-tags-stack*))

; �J�[�\���ʒu�̎��ʎq�� xyzzy �� syntax �ɍ��킹�Ď擾
(defun ctags-get-current-identifier ()
	(save-excursion
		(buffer-substring
		 (progn
			 (skip-syntax-spec-forward "w_")
			 (point))
		 (progn
			 (skip-syntax-spec-backward "w_")
			 (point)))))

; �ǂݍ��ݍς݂̃o�b�t�@���폜
(defun ctags-clean-tags-buffers ()
  (dolist (buffer *ctags-tags-buffer-list*)
    (delete-buffer buffer)))
  
