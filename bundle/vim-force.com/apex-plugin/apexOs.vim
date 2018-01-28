" This file is part of vim-force.com plugin
"   https://github.com/neowit/vim-force.com
" File: apexOs.vim
" Last Modified: 2014-05-06
" Author: Andrey Gavrikov 
" Maintainers: 
"
" OS specific methods
"
"
if exists("g:loaded_apexOs") || &compatible
  finish
endif
let g:loaded_apexOs = 1

" check that required global variables are defined
let s:requiredVariables = ["g:apex_backup_folder", "g:apex_temp_folder", "g:apex_properties_folder"]
for varName in s:requiredVariables
	if !exists(varName)
		echoerr "Please define ".varName." See :help force.com-settings"
	endif
endfor	

let s:is_windows = has("win32") || has("win64")

"Function: apexOs#isWindows() function {{{1
" check if current machine is running MS Windows
function! apexOs#isWindows()
	return s:is_windows
endfunction

"Function: s:let() function {{{2
" initialise given variable if it is not already set
"
"Args:
"var: the name of the variable to be initialised
"value: the value to initialise to
"
"Returns: 1 if the variable is set inside this method, otherwise 0
function! s:let(var, value)
    if !exists(a:var)
        exec 'let ' . a:var . ' = ' . "'" . substitute(a:value, "'", "''", "g") . "'"
        return 1
    endif
    return 0
endfunction

"Function: s:trim() function {{{1
" trim spaces at the end
"Args:
" str: input string
"Returns: trimmed string value or copy of existing string if nothing needed to
"be removed
function s:trim(str)
	return substitute(a:str,"^\\s\\+\\|\\s\\+$","","g") 
endfunction	

"""""""""""""""""""""""""""""""""""""""""""""""
" OS Dependent shell commands
"""""""""""""""""""""""""""""""""""""""""""""""
" space at the end of command is important
if s:is_windows
	call s:let('g:apex_binary_remove_dir', 'rmdir /s /q ')
else
	call s:let('g:apex_binary_create_dir', 'mkdir ')
	call s:let('g:apex_binary_remove_dir', 'rm -R ')
endif

"set desired API version
call s:let('g:apex_API_version', '37.0')

" set pollWaitMillis for ant tasks. See ant-salesforce.jar
" documentation for 'pollWaitMillis' parameter
" the smaller the value defined by pollWaitMillis the quicker deploy will
" finish, but on slow connections larger values, like 10000 may be necessary
call s:let('g:apex_pollWaitMillis', '1000') " 1 second
call s:let('g:apex_maxPollRequests', '1000') " 1000 polls


"""""""""""""""""""""""""""""""""""""""""""""""
" OS Dependent methods
"""""""""""""""""""""""""""""""""""""""""""""""
function! apexOs#browsedir(prompt, startDir)
	let fPath = getcwd()
	let prompt = 'Select Folder'
	if len(a:prompt) >0
		let prompt = a:prompt
	endif
	if len(a:startDir) >0
		let fPath = a:startDir
	endif
	if has("macunix") && v:version < 703 || v:version == 703 && !has("patch688")
		" in version of MacVim < 7.3.688 buil-in function browsedir() produces
		" file selection dialogue instead of folder selection, so have to use osascript instead
		let strCommand ='osascript  -e "tell application \"Finder\"" -e "activate" -e "set fpath to POSIX path of (choose folder default location \"'.fPath.'\" with prompt \"'.prompt.'\")" -e "return fpath" -e "end tell"'
		let fPath=system(strCommand)
		"clean path from new line characters returned by osascript
		let fPath = substitute(fPath, "\n", "", "")
	else
		" standard built-in method
		" http://code.google.com/p/macvim/issues/detail?id=425#c3
		" note: 'title' argument of MacVim browsedir() is ignored since open dialogs
		" are in fact sheets and have no title.
		let fPath = browsedir(prompt, fPath)
	endif	
	return fPath
endfunction	

function! apexOs#getTempFolder()
	return g:apex_temp_folder
endfunction	

function! apexOs#getBackupFolder()
	return g:apex_backup_folder
endfunction	

" OS dependent temporary directory create/delete
" Arguments:
" 1 - [optional]: 'wipe' - if specified then existing temp folder will be
" erased and re-created
function! apexOs#createTempDir(...)
	let tempFolderPath = apexOs#getTempFolder()
	let reCreate = (a:0 >0 && 'wipe' == a:1)

	if !isdirectory(apexOs#getTempFolder()) || reCreate
		if has("unix")
			" remove existing folder
			silent exe "!rm -R ". shellescape(tempFolderPath)
		elseif s:is_windows
			silent exe "!rd ".GetWin32ShortName(tempFolderPath)." /s /q "
		else
			echoerr "Not implemented"
			return ""
		endif
		" recreate temp folder
		call apexOs#createDir(tempFolderPath)
	endif
	return tempFolderPath
endfunction
" 
" Os dependent directory create
function! apexOs#createDir(path) abort
	let path = apexOs#removeTrailingPathSeparator(a:path)
	if isdirectory(path)
		call apexUtil#warning(path." already exists, skip createDir()")
		return
	endif	
	if has("unix")
		call mkdir(path, "p", 0700)
	elseif s:is_windows
		call mkdir(path, "p")
	else
		echoerr "Not implemented"
	endif
endfunction

" standard shellescape() function does not escape all necessary characters,
" e.g. ( and ) so have to use custom function
" TODO - test on win32
function! apexOs#shellescape(val)
	let val = shellescape(a:val)
	if has("unix")
		return escape(val, '%')
	endif
	return val
endfunction
" 
" Os dependent file copy
function! apexOs#copyFile(srcPath, destPath)
	let sourcePath = apexOs#shellescape(a:srcPath)
	let destinationPath = apexOs#shellescape(a:destPath)
	if has("unix")
		"echo "cp " . sourcePath . " " . destinationPath
		silent exe "!cp -p " . sourcePath . " " . destinationPath
	elseif s:is_windows
		"silent exe "!copy " . sourcePath . " " . destinationPath

		"readfile/writefile method is slower on the actual file copy part but
		"shall be not slower on the overal operation time because unlike
		"!copy it does not wait for a popup/close of cmd.exe window 
		let fl = readfile(a:srcPath, "b")
		call writefile(fl, a:destPath, "b")
	else
		echoerr "Not implemented"
	endif
	"check if copy succeeded
	if !filereadable(a:destPath)
		echoerr 'failed to copy '. a:srcPath . " to " . a:destPath
	endif	
endfunction

" remove trailing path separator
" i.e. make /path/to/folder from /path/to/folder/
function! apexOs#removeTrailingPathSeparator (path)
	return substitute (a:path, '[/\\]$', '', '')
endfun

" "foo/bar/buz/hoge" -> { head: "foo/bar/buz/", tail: "hoge" }
" current version is taken from fuzzy finder plugin
" alterntive version of this function can NOT be done with 
" fnamemodify(path, ':h') && fnamemodify(path, ':t')
" because fnamemodify('foo/bar/buz/hoge/', ':t') results in blank value
function! apexOs#splitPath(path)
	let path = apexOs#removeTrailingPathSeparator(a:path)
	let head = matchstr(path, '^.*[/\\]')
	return  {
				\   'head' : head,
				\   'tail' : path[strlen(head):]
				\ }
endfunction

" \ on Windows unless shellslash is set, / everywhere else.
function! apexOs#getPathSeparator()
  return !exists("+shellslash") || &shellslash ? '/' : '\'
endfunction


" returns list of paths.
" An argument for glob() is normalized in order to avoid a bug on Windows.
" taken from fuzzy finder plugin
function! apexOs#glob(expr)
  " Substitutes "\", because on Windows, "**\" doesn't include ".\",
  " but "**/" include "./". I don't know why.
  return split(glob(substitute(a:expr, '\', '/', 'g')), "\n")
endfunction

"
"Param: params - dictionary
"   - 'background' 0|1, if 0 then use system(), otherwise job_start()
function! apexOs#exe(command, params)
    if has_key(a:params, "background") && !a:params.background
        "echomsg "command=".a:command
        let command = a:command
        if apexOs#isWindows()
            " change all '\' in path to '/'
            let command = substitute(command, '\', '/', "g")
        endif    
        return system(command)
    else    
        let obj = {}
        function obj.callback(channel, msg)
            echo a:msg 
        endfunction    
        let job = job_start(a:command, {"callback": function(obj.callback)})

        let s:job = job
        return job
    endif
endfunction    

" @return: true of given path name has trailing path separator
" ex: 
"	echo hasTrailingPathSeparator("/my/path") = 0
"	echo hasTrailingPathSeparator("/my/path/") = 1
function! apexOs#hasTrailingPathSeparator(filePath)
	if match(a:filePath, '.*[/\\]$') >= 0
		return 1
	endif	
	return 0
endfunction	

" 
" concatenate file path components
" Args: supports two versions of arguments
"	- single argument of type List
"	  e.g. apexOs#joinPath(['/path', 'to' , 'file']) - '/path/to/file'
"	- separate arguments 
"	  e.g. apexOs#joinPath('/path', 'to' , 'file') - '/path/to/file'
"
function! apexOs#joinPath(...)
	if a:0 < 1
		throw "Argument required."
	endif	
	let filePathList = []
	if 3 == type(a:1) " first argument is a List
		let filePathList = a:1
	else "path components are passed as separate arguments
		let filePathList = a:000
	endif
	let resPath = ''
	for path in filePathList
		if len(resPath)>0 
			if apexOs#hasTrailingPathSeparator(resPath)
				let resPath .= path
			else
				let resPath = join([resPath, path], apexOs#getPathSeparator())
			endif
		else
			let resPath = path
		endif	
	endfor
	return resPath
endfunction	

" check if provided string looks like full or relative path
" e.g. (unix)
" /, /usr, /my/log/path = full paths
" usr, my/log/path = relative paths
" e.g. (windows)
" c:\, c:\usr, c:\my\log\path = full paths
" usr, my\log\path = relative paths
"
"Param1: path to check
"Returns: 1 - full path, 0 - relative path
function! apexOs#isFullPath(path)
	let l:isFullPath = a:path =~? '^\(\a:\\\|/\)'
	return l:isFullPath
endfunction
	
