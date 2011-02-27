;;; -*- Mode: lisp -*-
; ctags.l
;
; ctags.exe を使用してタグジャンプを行う機能を提供
; ctags 日本語対応版 http://hp.vector.co.jp/authors/VA025040/ctags/
;
; by MATSUOKA Hiroshi <matsuoka@fun.sci.fukuoka-u.ac.jp>
;
; .xyzzy sample
; (load-library "ctags")
; ; ctags.exe へのパス
; (setf *ctags-command-path* (merge-pathnames "etc/ctags.exe" (si:system-root)))
; ; ctags.exe へのその他のオプション
; ;(setf *ctags-command-option* "")
; (global-set-key #\M-. 'ctags-jump-tag)
; (global-set-key #\M-\, 'ctags-back-tag-jump)
; (global-set-key #\M-/ 'ctags-make-tags-file)
; ;(global-set-key #\M-/ 'ctags-make-tags-file-recursive)
;
; [2005/09/28] matsuoka@fun.sci.fukuoka-u.ac.jp
; 作成。
; [2007/12/02] matsuoka@fun.sci.fukuoka-u.ac.jp
; ハッシュベースから隠しバッファでの検索に切り替え
; [2007/12/08] matsuoka@fun.sci.fukuoka-u.ac.jp
; NANRI さんの指摘を受けて tags で / がクォートされてるのをはずす
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
; ctags.exe の場所とオプション
(defvar *ctags-command-path* nil)
(defvar *ctags-command-option* "")
; tags を読み込むバッファ名のプレフィクス
(defvar *ctags-tags-buffer-prefix* " *Ctags ")
; tags を読み込んだバッファの一覧
(defvar *ctags-tags-buffer-list* nil)
; バッファローカルなタグスタック
(defvar-local *ctags-tags-stack* nil)
; tags として使用するバッファ名
(defvar-local *ctags-tags-buffer-name* nil)

; tags ファイルの作成(サブディレクトリ抜き)
(defun ctags-make-tags-file (dir)
	(interactive "DMakeTagsTo: "
		:default01 (if (get-buffer-file-name)
									 (pathname-directory (get-buffer-file-name))
								 ""))
	(ctags-execute-command dir))

; tags ファイルの作成(サブディレクトリ含む)
(defun ctags-make-tags-file-recursive (dir)
	(interactive "DMakeTagsTo: "
		:default01 (if (get-buffer-file-name)
									 (pathname-directory (get-buffer-file-name))
								 ""))
	(ctags-execute-command dir t))

; ctags の実行
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


; tags ファイルの読み込み(ディレクトリ指定)
(defun ctags-make-tags-map (dir)
  (interactive "DReadTagsFrom: "
    :default01 (if (get-buffer-file-name)
                   (pathname-directory (get-buffer-file-name))
                 ""))
  (cond
   ((and
     (null *ctags-tags-buffer-name*)
     (not (file-exist-p (merge-pathnames "tags" dir))))
    (when (yes-or-no-p "tags ファイルがありません。作成しますか?")
      (call-interactively 'ctags-make-tags-file-recursive)))
   ((or (null *ctags-tags-buffer-name*)
        (yes-or-no-p "既に tags を読み込んでます。上書きしますか?"))
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

; バッファの現在行と行頭行末のポイントを返す
(defun ctags-get-current-line ()
  (let ((end (progn (goto-eol) (point)))
        (begin (progn (goto-bol) (point))))
    (cons (buffer-substring begin end) (cons begin end))))

; tags を読み込んだバッファから目的の識別子と一致するリストを返却
(defun ctags-search-tag (word)
  (save-excursion
    (switch-to-buffer *ctags-tags-buffer-name*)
    (goto-char 0)
    (let ((tags nil)
          (regexp (compile-regexp (format nil "^~A\t\\([^\t]+\\)\t\\(.+\\);\"" (regexp-quote word)))))
      (while (scan-buffer regexp :no-dup t :regexp t)
        (push (cons (merge-pathnames (match-string 1) ctags-tags-file-dir-path) (match-string 2)) tags))
      tags)))

; タグジャンプ
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

; バックタグジャンプ
(defun ctags-back-tag-jump ()
	(interactive)
	(when *ctags-tags-buffer-name*
		(if (null *ctags-tags-stack*)
        (message "no stack for back tag jump")
      (ctags-goto-tag1 (pop *ctags-tags-stack*)))))

; 任意のタグに移動(スタックを積む)
(defun ctags-goto-tag (tag)
  (ctags-push-current-marker)
  (ctags-goto-tag1 tag))

; 任意のタグに移動
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

; 複数のタグから次のジャンプ先を決定する
(defun ctags-select-next-tag (tags)
  (ctags-goto-tag (ctags-select-tag tags)))

; 現在のスタックの中を選択して戻る
(defun ctags-select-stack ()
  (interactive)
  (if (not *ctags-tags-stack*)
      (msgbox "スタックがありません")
    (let ((tag (ctags-select-tag *ctags-tags-stack*)))
      (when tag
        (setf *ctags-tags-stack*
              (cdr (member tag *ctags-tags-stack* :test 'eq)))
        (ctags-goto-tag1 tag)))))

; 複数のタグよりミニバッファでジャンプ先を選択する。tag を返却
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


; 現在位置をローカルのスタックに積む
(defun ctags-push-current-marker ()
  (push (cons (get-buffer-file-name) (point))
        *ctags-tags-stack*))

; カーソル位置の識別子を xyzzy の syntax に合わせて取得
(defun ctags-get-current-identifier ()
	(save-excursion
		(buffer-substring
		 (progn
			 (skip-syntax-spec-forward "w_")
			 (point))
		 (progn
			 (skip-syntax-spec-backward "w_")
			 (point)))))

; 読み込み済みのバッファを削除
(defun ctags-clean-tags-buffers ()
  (dolist (buffer *ctags-tags-buffer-list*)
    (delete-buffer buffer)))
  

