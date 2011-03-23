{-# OPTIONS -cpp #-}
{-# LANGUAGE CPP, ForeignFunctionInterface #-}

------------------------------------------------------------------------
-- Program for converting .hsc files to .hs files, by converting the
-- file into a C program which is run to generate the Haskell source.
-- Certain items known only to the C compiler can then be used in
-- the Haskell module; for example #defined constants, byte offsets
-- within structures, etc.
--
-- See the documentation in the Users' Guide for more details.

#if defined(__GLASGOW_HASKELL__) && !defined(BUILD_NHC)
#include "../../includes/ghcconfig.h"
#endif

import Control.Monad            ( liftM )
import Data.List                ( isSuffixOf )
import System.Console.GetOpt

#if defined(mingw32_HOST_OS)
import Foreign
import Foreign.C.String
#endif
import System.Directory         ( doesFileExist )
import System.Environment       ( getProgName, getArgs )
import System.Exit              ( ExitCode(..), exitWith )
import System.IO

#ifdef BUILD_NHC
import System.Directory         ( getCurrentDirectory )
#else
import Data.Version             ( showVersion )
import Paths_hsc2hs as Main     ( getDataFileName, version )
#endif

import HSCParser
import DirectCodegen

#ifdef BUILD_NHC
getDataFileName s = do here <- getCurrentDirectory
                       return (here++"/"++s)
version = "0.67" -- TODO!!!
showVersion = id
#endif

versionString :: String
versionString = "hsc2hs version " ++ showVersion version ++ "\n"

template_flag :: Flag -> Bool
template_flag (Template _) = True
template_flag _		   = False

include :: String -> Flag
include s@('\"':_) = Include s
include s@('<' :_) = Include s
include s          = Include ("\""++s++"\"")

define :: String -> Flag
define s = case break (== '=') s of
    (name, [])      -> Define name Nothing
    (name, _:value) -> Define name (Just value)

options :: [OptDescr Flag]
options = [
    Option ['o'] ["output"]     (ReqArg Output     "FILE")
        "name of main output file",
    Option ['t'] ["template"]   (ReqArg Template   "FILE")
        "template file",
    Option ['c'] ["cc"]         (ReqArg Compiler   "PROG")
        "C compiler to use",
    Option ['l'] ["ld"]         (ReqArg Linker     "PROG")
        "linker to use",
    Option ['C'] ["cflag"]      (ReqArg CompFlag   "FLAG")
        "flag to pass to the C compiler",
    Option ['I'] []             (ReqArg (CompFlag . ("-I"++)) "DIR")
        "passed to the C compiler",
    Option ['L'] ["lflag"]      (ReqArg LinkFlag   "FLAG")
        "flag to pass to the linker",
    Option ['i'] ["include"]    (ReqArg include    "FILE")
        "as if placed in the source",
    Option ['D'] ["define"]     (ReqArg define "NAME[=VALUE]")
        "as if placed in the source",
    Option []    ["no-compile"] (NoArg  NoCompile)
        "stop after writing *_hsc_make.c",
    Option ['v'] ["verbose"]    (NoArg  Verbose)
        "dump commands to stderr",
    Option ['?'] ["help"]       (NoArg  Help)
        "display this help and exit",
    Option ['V'] ["version"]    (NoArg  Version)
        "output version information and exit" ]

main :: IO ()
main = do
    prog <- getProgramName
    let header = "Usage: "++prog++" [OPTIONS] INPUT.hsc [...]\n"
    args <- getArgs
    let (flags, files, errs) = getOpt Permute options args

    -- If there is no Template flag explicitly specified, try
    -- to find one. We first look near the executable.  This only
    -- works on Win32 or Hugs (getExecDir). If this finds a template
    -- file then it's certainly the one we want, even if hsc2hs isn't
    -- installed where we told Cabal it would be installed.
    --
    -- Next we try the location we told Cabal about.
    --
    -- If neither of the above work, then hopefully we're on Unix and
    -- there's a wrapper script which specifies an explicit template flag.
    mb_libdir <- getLibDir

    flags_w_tpl0 <-
        if any template_flag flags then return flags
        else do mb_templ1 <-
                   case mb_libdir of
                   Nothing   -> return Nothing
                   Just path -> do
                   -- Euch, this is horrible. Unfortunately
                   -- Paths_hsc2hs isn't too useful for a
                   -- relocatable binary, though.
                     let 
#if defined(NEW_GHC_LAYOUT)
                         templ1 = path ++ "/template-hsc.h"
#else
                         templ1 = path ++ "/hsc2hs-" ++ showVersion Main.version ++ "/template-hsc.h"
#endif
                         incl = path ++ "/include/"
                     exists1 <- doesFileExist templ1
                     if exists1
                        then return $ Just (Template templ1,
                                            CompFlag ("-I" ++ incl))
                        else return Nothing
                case mb_templ1 of
                    Just (templ1, incl) -> return (templ1 : flags ++ [incl])
                    Nothing -> do
                        templ2 <- getDataFileName "template-hsc.h"
                        exists2 <- doesFileExist templ2
                        if exists2 then return (Template templ2 : flags)
                                   else return flags

    -- take only the last --template flag on the cmd line
    let
      (before,tpl:after) = break template_flag (reverse flags_w_tpl0)
      flags_w_tpl = reverse (before ++ tpl : filter (not.template_flag) after)

    case (files, errs) of
        (_, _)
            | any isHelp    flags_w_tpl -> bye (usageInfo header options)
            | any isVersion flags_w_tpl -> bye versionString
            where
            isHelp    Help    = True; isHelp    _ = False
            isVersion Version = True; isVersion _ = False
        ((_:_), []) -> mapM_ (processFile flags_w_tpl mb_libdir) files
        (_,     _ ) -> die (concat errs ++ usageInfo header options)

getProgramName :: IO String
getProgramName = liftM (`withoutSuffix` "-bin") getProgName
   where str `withoutSuffix` suff
            | suff `isSuffixOf` str = take (length str - length suff) str
            | otherwise             = str

bye :: String -> IO a
bye s = putStr s >> exitWith ExitSuccess

processFile :: [Flag] -> Maybe String -> String -> IO ()
processFile flags mb_libdir name
  = do let file_name = dosifyPath name
       h <- openBinaryFile file_name ReadMode
       -- use binary mode so we pass through UTF-8, see GHC ticket #3837
       -- But then on Windows we end up turning things like
       --     #let alignment t = e^M
       -- into
       --     #define hsc_alignment(t ) printf ( e^M);
       -- which gcc doesn't like, so strip out any ^M characters.
       s <- hGetContents h
       let s' = filter ('\r' /=) s
       case parser of
    	   Parser p -> case p (SourcePos file_name 1) s' of
    	       Success _ _ _ toks -> output mb_libdir flags file_name toks
    	       Failure (SourcePos name' line) msg ->
    		   die (name'++":"++show line++": "++msg++"\n")

getLibDir :: IO (Maybe String)
#if defined(NEW_GHC_LAYOUT)
getLibDir = fmap (fmap (++ "/lib")) $ getExecDir "/bin/hsc2hs.exe"
#else
getLibDir = getExecDir "/bin/hsc2hs.exe"
#endif

-- (getExecDir cmd) returns the directory in which the current
--                  executable, which should be called 'cmd', is running
-- So if the full path is /a/b/c/d/e, and you pass "d/e" as cmd,
-- you'll get "/a/b/c" back as the result
getExecDir :: String -> IO (Maybe String)
getExecDir cmd =
    getExecPath >>= maybe (return Nothing) removeCmdSuffix
    where unDosifyPath = subst '\\' '/'
          initN n = reverse . drop n . reverse
          removeCmdSuffix = return . Just . initN (length cmd) . unDosifyPath

getExecPath :: IO (Maybe String)
#if defined(mingw32_HOST_OS)
getExecPath =
     allocaArray len $ \buf -> do
         ret <- getModuleFileName nullPtr buf len
         if ret == 0 then return Nothing
	             else liftM Just $ peekCString buf
    where len = 2048 -- Plenty, PATH_MAX is 512 under Win32.

foreign import stdcall unsafe "GetModuleFileNameA"
    getModuleFileName :: Ptr () -> CString -> Int -> IO Int32
#else
getExecPath = return Nothing
#endif
