--
-- Copyright (c) 2014 Citrix Systems, Inc.
-- 
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
-- 
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
--

-- Configuration of XenMgr
{-# LANGUAGE ScopedTypeVariables #-}

module XenMgr.Config
                 (
                   appIsoPath
                 , appAutoStart
                 , appPvmAutoStartDelay
                 , appSvmAutoStartDelay
                 , appOverwriteServiceVmSettings
                 , appXcDiagTimeout
                 , appIdleTimeThreshold
                 , appV4VHostsFile
                 , appMultiGpuPt
                 , appSeamlessTrafficDefault
                 , appBypassSha1SumChecks
                 , appGetPlatformCryptoKeyDirs
                 , appGetPlatformFlavour
                 , appGetGuestOnlyNetworking
                 , appGetV4VFirewall
                 , appSetV4VFirewall
                 , appSetIsoPath
                 , appSetAutoStart
                 , appSetPvmAutoStartDelay
                 , appSetSvmAutoStartDelay
                 , appSetOverwriteServiceVmSettings
                 , appSetXcDiagTimeout
                 , appSetIdleTimeThreshold
                 , appSetV4VHostsFile
                 , appSetPlatformCryptoKeyDirs
                 , appConfigurableSaveChangesAcrossReboots
                 , appGetAutolockCdDrives
                 , appSetAutolockCdDrives
                 , appGetEnableSsh, appSetEnableSsh
                 , appGetEnableV4vSsh, appSetEnableV4vSsh
                 , appGetEnableDom0Networking, appSetEnableDom0Networking
                 , appGetDom0MemTargetMIB, appSetDom0MemTargetMIB
                 , appGetSwitcherEnabled, appSetSwitcherEnabled
                 , appGetSwitcherSelfSwitchEnabled, appSetSwitcherSelfSwitchEnabled
                 , appGetSwitcherKeyboardFollowsMouse, appSetSwitcherKeyboardFollowsMouse
                 , appGetSwitcherResistance, appSetSwitcherResistance
                 , appGetSwitcherStatusReportEnabled, appSetSwitcherStatusReportEnabled
                 , appGetDrmGraphics, appSetDrmGraphics
                 , appGetSupportedLanguages
                 , appGetLanguage, appSetLanguage
                 , BuildInfo(..)
                 , readBuildInfo
                 ) where

import Control.Monad
import Control.Applicative
import Control.Concurrent
import qualified Data.Map as M
import qualified Control.Exception as E
import Data.List
import Data.Maybe
import Data.Char
import System.IO
import System.IO.Unsafe
import System.Posix.Files
import Directory

import Tools.Text
import Tools.Misc
import Tools.Process
import Tools.File

import XenMgr.Rpc
import XenMgr.Errors
import XenMgr.Db

-- CONFIG on DBUS !

data BuildInfo = BuildInfo {
      biBuildNum        :: String
    , biBuildDate       :: String
    , biBuildBranch     :: String
    , biVersion         :: String
    , biRelease         :: String
    , biTools           :: String
    }

readBuildInfo :: IO BuildInfo
readBuildInfo =
    parse <$> readFile "/etc/issue"
  where
    parse  = fromMap . toMap . lines
    toMap  = foldl' insert M.empty
    insert m line = case map strip . split '=' $ line of
                      [k,v] -> M.insert k v m
                      _     -> m
    fromMap m = BuildInfo {
                  biBuildNum    = maybe "" id (M.lookup "build" m)
                , biBuildDate   = maybe "" id (M.lookup "build_date" m)
                , biBuildBranch = maybe "" id (M.lookup "build_branch" m)
                , biVersion     = maybe "" id (M.lookup "version" m)
                , biRelease     = maybe "" id (M.lookup "release" m)
                , biTools       = maybe "" id (M.lookup "tools" m)
                }

-- Path to ISO cd images
appIsoPath :: Rpc FilePath
appIsoPath =  do
    dbMaybeRead "/xenmgr/isos" >>= f where f Nothing  = return "/storage/isos"
                                           f (Just p) = return p

appSetIsoPath :: String -> Rpc ()
appSetIsoPath path = dbWrite "/xenmgr/isos" path

-- Is autostart function active (by default it is)
appAutoStart :: Rpc Bool
appAutoStart = do
    dbMaybeRead "/xenmgr/autostart" >>= f where f Nothing  = return True
                                                f (Just v) = return v

appSetAutoStart :: Bool -> Rpc ()
appSetAutoStart as = dbWrite "/xenmgr/autostart" as

appPvmAutoStartDelay :: Rpc Int
appPvmAutoStartDelay  = do
    dbMaybeRead "/xenmgr/pvm-autostart-delay" >>= f where f Nothing  = return 0
                                                          f (Just v) = return v
appSetPvmAutoStartDelay :: Int -> Rpc ()
appSetPvmAutoStartDelay d = dbWrite "/xenmgr/pvm-autostart-delay" d

appSvmAutoStartDelay :: Rpc Int
appSvmAutoStartDelay  = do
    dbMaybeRead "/xenmgr/svm-autostart-delay" >>= f where f Nothing  = return 0
                                                          f (Just v) = return v
appSetSvmAutoStartDelay :: Int -> Rpc ()
appSetSvmAutoStartDelay d = dbWrite "/xenmgr/svm-autostart-delay" d

-- defaults to true
appOverwriteServiceVmSettings :: String -> Rpc Bool
appOverwriteServiceVmSettings tag =
    do dbMaybeRead ("/xenmgr/overwrite-" ++ tag ++ "-settings") >>= f where f Nothing  = return True
                                                                            f (Just v) = return v
appSetOverwriteServiceVmSettings :: String -> Bool -> Rpc ()
appSetOverwriteServiceVmSettings tag value = dbWrite ("/xenmgr/overwrite-" ++ tag ++ "-settings") value

-- defaults to 120s
appXcDiagTimeout :: Rpc Int
appXcDiagTimeout =
    dbMaybeRead "/xenmgr/xc-diag-timeout" >>= return . fromMaybe 180

appSetXcDiagTimeout :: Int -> Rpc ()
appSetXcDiagTimeout to = dbWrite "/xenmgr/xc-diag-timeout" to

-- defaults to 0s
appIdleTimeThreshold :: Rpc Int
appIdleTimeThreshold =
    dbMaybeRead "/xenmgr/idle-time-threshold" >>= return . fromMaybe 0

appSetIdleTimeThreshold :: Int -> Rpc ()
appSetIdleTimeThreshold to = dbWrite "/xenmgr/idle-time-threshold" to


-- Should we be updating /etc/hosts with v4v addresses. defaults to true
appV4VHostsFile :: Rpc Bool
appV4VHostsFile = dbMaybeRead "/xenmgr/v4v-hosts-file" >>= return . fromMaybe True

appSetV4VHostsFile :: Bool -> Rpc ()
appSetV4VHostsFile v = dbWrite "/xenmgr/v4v-hosts-file" v

-- Should we bypass disk hash checks
appBypassSha1SumChecks :: Rpc Bool
appBypassSha1SumChecks = dbMaybeRead "/xenmgr/bypass-sha1sum-checks" >>= return . fromMaybe False

-- Should we allow dual/multi passthrough GPU feature
appMultiGpuPt :: Rpc Bool
appMultiGpuPt = do
  caps <- liftIO readCaps
  return $ M.lookup "secondary-gpu-pt" caps == Just "true"

--
appGetPlatformCryptoKeyDirs :: Rpc String
appGetPlatformCryptoKeyDirs = dbMaybeRead "/xenmgr/platform-crypto-key-dirs" >>= return . fromMaybe "/config/platform-crypto-keys"

appSetPlatformCryptoKeyDirs :: String -> Rpc ()
appSetPlatformCryptoKeyDirs paths = dbWrite "/xenmgr/platform-crypto-key-dirs" paths

appGetPlatformFlavour :: IO String
appGetPlatformFlavour =
    do exists <- doesFileExist "/etc/xenclient.flavour"
       if exists
          then chomp <$> readFile "/etc/xenclient.flavour"
          else return "default"

appGetGuestOnlyNetworking :: Rpc Bool
appGetGuestOnlyNetworking =
    dbMaybeRead "/xenmgr/guest-only-networking" >>= return . fromMaybe False

appGetV4VFirewall :: Rpc Bool
appGetV4VFirewall = dbReadWithDefault True "/xenmgr/v4v-firewall"

appSetV4VFirewall :: Bool -> Rpc ()
appSetV4VFirewall v = dbWrite "/xenmgr/v4v-firewall" v

appConfigurableSaveChangesAcrossReboots :: Rpc Bool
appConfigurableSaveChangesAcrossReboots = do
  caps <- liftIO readCaps
  return $ M.lookup "configurable-save-changes-across-reboots" caps == Just "true"

appSeamlessTrafficDefault :: Rpc Bool
appSeamlessTrafficDefault = do
  caps <- liftIO readCaps
  return $ M.lookup "seamless-traffic-default" caps == Just "true"

appGetEnableSsh :: Rpc Bool
appGetEnableSsh = liftIO $ doesFileExist "/config/etc/ssh/enabled"

appSetEnableSsh :: Bool -> Rpc ()
appSetEnableSsh False =
    liftIO $ do
      exist <- doesFileExist "/config/etc/ssh/enabled"
      if exist then removeFile "/config/etc/ssh/enabled" else return ()
      safeSpawnShell "/etc/init.d/sshd restart"
      return ()
appSetEnableSsh True =
    liftIO $ do
      writeFile "/config/etc/ssh/enabled" ""
      safeSpawnShell "/etc/init.d/sshd restart"
      return ()

appGetEnableV4vSsh :: Rpc Bool
appGetEnableV4vSsh = not <$> liftIO (doesFileExist "/config/etc/ssh/disable-v4v")

appSetEnableV4vSsh :: Bool -> Rpc ()
appSetEnableV4vSsh False =
    liftIO $ do
      writeFile "/config/etc/ssh/disable-v4v" ""
      safeSpawnShell "/etc/init.d/sshd_v4v restart"
      return ()

appSetEnableV4vSsh True =
    liftIO $ do
      exist <- doesFileExist "/config/etc/ssh/disable-v4v"
      if exist then removeFile "/config/etc/ssh/disable-v4v" else return ()
      safeSpawnShell "/etc/init.d/sshd_v4v restart"
      return ()

appGetEnableDom0Networking :: Rpc Bool
appGetEnableDom0Networking = liftIO $ not <$> doesFileExist "/config/system/dom0-networking-disabled"
appSetEnableDom0Networking True =
    liftIO $ do
      exist <- doesFileExist "/config/system/dom0-networking-disabled"
      if exist then removeFile "/config/system/dom0-networking-disabled" else return ()
appSetEnableDom0Networking False =
    liftIO $ writeFile "/config/system/dom0-networking-disabled" ""

appGetDom0MemTargetMIB :: Rpc Int
appGetDom0MemTargetMIB = dbReadWithDefault 256 "/dom0-mem-target-mib"

appSetDom0MemTargetMIB :: Int -> Rpc ()
appSetDom0MemTargetMIB mib = dbWrite "/dom0-mem-target-mib" (show mib)

appGetSwitcherEnabled :: Rpc Bool
appGetSwitcherEnabled = dbReadWithDefault True "/switcher/enabled"
appSetSwitcherEnabled v = dbWrite "/switcher/enabled" v

appGetSwitcherSelfSwitchEnabled :: Rpc Bool
appGetSwitcherSelfSwitchEnabled =
    not <$> dbReadWithDefault True "/switcher/self-switch-disabled"

appSetSwitcherSelfSwitchEnabled v = dbWrite "/switcher/self-switch-disabled" (not v)

appGetSwitcherKeyboardFollowsMouse :: Rpc Bool
appGetSwitcherKeyboardFollowsMouse = dbReadWithDefault False "/switcher/keyboard_follows_mouse"
appSetSwitcherKeyboardFollowsMouse v = dbWrite "/switcher/keyboard_follows_mouse" v

appGetSwitcherResistance :: Rpc Int
appGetSwitcherResistance = dbReadWithDefault 10 "/switcher/resistance"

appSetSwitcherResistance :: Int -> Rpc ()
appSetSwitcherResistance v = dbWrite "/switcher/resistance" v

appGetSwitcherStatusReportEnabled :: Rpc Bool
appGetSwitcherStatusReportEnabled = dbReadWithDefault True "/switcher/status-report-enabled"
appSetSwitcherStatusReportEnabled v = dbWrite "/switcher/status-report-enabled" v

appGetSupportedLanguages :: Rpc [String]
appGetSupportedLanguages = parse <$> liftM (M.lookup "supported-languages") (liftIO readCaps) where
    parse Nothing   = []
    parse (Just ls) = words ls

appGetLanguage :: Rpc String
appGetLanguage =
    fromMaybe "en-us" . fmap dequote . lookup "LANGUAGE" <$> (liftIO $ readDictFile "/config/language.conf")
    where
      dequote ('\'':cs) = reverse $ dequote (reverse cs)
      dequote cs = cs

appSetLanguage :: String -> Rpc ()
appSetLanguage l = do
  assert_contains l =<< appGetSupportedLanguages
  liftIO $ saveDictFile "/config/language.conf" [("LANGUAGE",quote l)]
  where
    quote x = "'" ++ x ++ "'"
    assert_contains l ls
        | l `elem` ls = return ()
        | otherwise   = failUnsupportedLanguage

appGetAutolockCdDrives :: Rpc Bool
appGetAutolockCdDrives = dbReadWithDefault True "/xenmgr/autolock-cd-drives"

appSetAutolockCdDrives :: Bool -> Rpc ()
appSetAutolockCdDrives v = dbWrite "/xenmgr/autolock-cd-drives" v

capsCache :: MVar (Maybe (M.Map String String))
{-# NOINLINE capsCache #-}
capsCache = unsafePerformIO $ newMVar Nothing

readCaps :: IO (M.Map String String)
readCaps = modifyMVar capsCache get where
  get v@(Just m) = return (v,m)
  get Nothing = do
    flavour <- appGetPlatformFlavour
    v <- parse <$> readFile ("/etc/caps." ++ flavour)
    return (Just v, v)

  parse contents = foldl' mk_map M.empty . catMaybes . map parse_line $ lines contents
  parse_line l =
        case split '=' l of
          [ left, right ] -> from_equals left right
          _ -> Nothing
  from_equals l r =
    let ( l', r' ) = ( strip l, strip r ) in
    Just (l', r')
  mk_map m (key,val) =  M.insert key_l val_l m
    where key_l = map toLower key
          val_l = map toLower val

readDictFile :: FilePath -> IO [(String,String)]
readDictFile path =
    do exist <- doesFileExist path
       if not exist
          then return []
          else dictFile <$> readFileStrict path

saveDictFile :: FilePath -> [(String,String)] -> IO ()
saveDictFile path = writeFile path . dictFileStr

dictFile :: String -> [ (String,String) ]
dictFile = catMaybes . map (safeHead2 . split '=') . lines
    where
      safeHead2 (k:v:_) = Just (strip k,strip v)
      safeHead2 _ = Nothing

dictFileStr :: [(String,String)] -> String
dictFileStr = unlines . map mkline where mkline (k,v) = k ++ "=" ++ v

drmScript :: [String] -> IO String
drmScript opts = readProcessOrDie "/usr/share/openxt/drm_graphics_option.sh" opts ""

appGetDrmGraphics :: Rpc Bool
appGetDrmGraphics = liftIO $ do
  v <- E.try (parse . chomp <$> drmScript ["-g"])
  case v of
    Right v' -> return v'
    Left (e :: E.SomeException) -> return False
  where
    parse "true" = True
    parse _ = False

appSetDrmGraphics :: Bool -> Rpc ()
appSetDrmGraphics v = liftIO $
  void $ drmScript ["-u", "-s", if v then "true" else "false"]
