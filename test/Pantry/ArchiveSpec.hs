{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}

module Pantry.ArchiveSpec
  ( spec
  ) where

import           Data.Maybe ( fromJust )
import           Pantry
import           Path.IO ( resolveFile' )
import           RIO
import           RIO.Text as T
import           Test.Hspec

data TestLocation
  = TLFilePath String
  | TLUrl Text

data TestArchive = TestArchive
  { testLocation :: !TestLocation
  , testSubdir :: !Text
  }

getRawPackageLocationIdent' :: TestArchive -> IO PackageIdentifier
getRawPackageLocationIdent' TestArchive{..} = do
  testLocation' <- case testLocation of
    TLFilePath relPath -> do
      absPath <- resolveFile' relPath
      pure $ ALFilePath $ ResolvedPath
        { resolvedRelative = RelFilePath $ fromString relPath
        , resolvedAbsolute = absPath
        }
    TLUrl url -> pure $ ALUrl url
  let archive = RawArchive
        { raLocation = testLocation'
        , raHash = Nothing
        , raSize = Nothing
        , raSubdir = testSubdir
        }
  runPantryApp $ getRawPackageLocationIdent $ RPLIArchive archive metadata
  where
    metadata = RawPackageMetadata
      { rpmName = Nothing
      , rpmVersion = Nothing
      , rpmTreeKey = Nothing
      }

parsePackageIdentifier' :: String -> PackageIdentifier
parsePackageIdentifier' = fromJust . parsePackageIdentifier

urlToStackCommit :: Text -> TestLocation
urlToStackCommit commit = TLUrl $ T.concat
  [ "https://github.com/commercialhaskell/stack/archive/"
  , commit
  , ".tar.gz"
  ]

treeWithoutCabalFile :: Selector PantryException
treeWithoutCabalFile (TreeWithoutCabalFile _) = True
treeWithoutCabalFile _ = False

spec :: Spec
spec = do
  it "finds cabal file from tarball" $ do
    ident <- getRawPackageLocationIdent' TestArchive
      { testLocation = TLFilePath "attic/package-0.1.2.3.tar.gz"
      , testSubdir = ""
      }
    ident `shouldBe` parsePackageIdentifier' "package-0.1.2.3"
  it "finds cabal file from tarball with subdir '.'" $ do
    ident <- getRawPackageLocationIdent' TestArchive
      { testLocation = TLFilePath "attic/package-0.1.2.3.tar.gz"
      , testSubdir = "."
      }
    ident `shouldBe` parsePackageIdentifier' "package-0.1.2.3"
  it "finds cabal file from tarball with a package.yaml" $ do
    ident <- getRawPackageLocationIdent' TestArchive
      { testLocation = TLFilePath "attic/hpack-0.1.2.3.tar.gz"
      , testSubdir = ""
      }
    ident `shouldBe` parsePackageIdentifier' "hpack-0.1.2.3"
  it "finds cabal file from tarball with subdir '.' with a package.yaml" $ do
    ident <- getRawPackageLocationIdent' TestArchive
      { testLocation = TLFilePath "attic/hpack-0.1.2.3.tar.gz"
      , testSubdir = "."
      }
    ident `shouldBe` parsePackageIdentifier' "hpack-0.1.2.3"
  it "finds cabal file from tarball with subdir 'subs/pantry/'" $ do
    ident <- getRawPackageLocationIdent' TestArchive
      { testLocation = urlToStackCommit "2b846ff4fda13a8cd095e7421ce76df0a08b10dc"
      , testSubdir = "subs/pantry/"
      }
    ident `shouldBe` parsePackageIdentifier' "pantry-0.1.0.0"
  it "matches whole directory name" $
    getRawPackageLocationIdent' TestArchive
      { testLocation = urlToStackCommit "2b846ff4fda13a8cd095e7421ce76df0a08b10dc"
      , testSubdir = "subs/pant"
      }
    `shouldThrow` treeWithoutCabalFile
  it "follows symlinks to directories" $ do
    ident <- getRawPackageLocationIdent' TestArchive
      { testLocation = TLFilePath "attic/symlink-to-dir.tar.gz"
      , testSubdir = "symlink"
      }
    ident `shouldBe` parsePackageIdentifier' "foo-1.2.3"
  it "finds cabal file from gitlab//tahoe-lafs/tahoe tarball" $ do
    ident <- getRawPackageLocationIdent' TestArchive
      { testLocation = TLUrl "https://gitlab.com/tahoe-lafs/tahoe-great-black-swamp-types/-/archive/depfix/tahoe-great-black-swamp-types-depfix.tar.gz"
      , testSubdir = "."
      }
    ident `shouldBe` parsePackageIdentifier' "tahoe-great-black-swamp-types-0.6.0.0"
  it "finds cabal file from gitlab//philderbeast/tahoe tarball" $ do
    ident <- getRawPackageLocationIdent' TestArchive
      { testLocation = TLUrl "https://gitlab.com/philderbeast/tahoe-great-black-swamp-types/-/archive/depfix/tahoe-great-black-swamp-types-depfix.tar.gz"
      , testSubdir = "."
      }
    ident `shouldBe` parsePackageIdentifier' "tahoe-great-black-swamp-types-0.6.0.0"
  it "finds cabal file from gitlab//philderbeast/tahoe tarball with subdir 'swamp-types/'" $ do
    ident <- getRawPackageLocationIdent' TestArchive
      { testLocation = TLUrl "https://gitlab.com/philderbeast/tahoe-great-black-swamp-types/-/archive/tahoe-monorepo-one-deep/tahoe-great-black-swamp-types-tahoe-monorepo-one-deep.tar.gz"
      , testSubdir = "swamp-types"
      }
    ident `shouldBe` parsePackageIdentifier' "tahoe-great-black-swamp-types-0.6.0.0"
  it "finds cabal file from gitlab//philderbeast/tahoe tarball with subdir 'swamp/types/'" $ do
    ident <- getRawPackageLocationIdent' TestArchive
      { testLocation = TLUrl "https://gitlab.com/philderbeast/tahoe-great-black-swamp-types/-/archive/tahoe-monorepo/tahoe-great-black-swamp-types-tahoe-monorepo.tar.gz"
      , testSubdir = "swamp/types"
      }
    ident `shouldBe` parsePackageIdentifier' "tahoe-great-black-swamp-types-0.6.0.0"
  it "finds cabal file from github//philderbeast/tahoe tarball" $ do
    ident <- getRawPackageLocationIdent' TestArchive
      { testLocation = TLUrl "https://github.com/philderbeast/tahoe-great-black-swamp-types/archive/fa7bd9edc495018bd4bac605f03289ed848e2200.tar.gz"
      , testSubdir = "."
      }
    ident `shouldBe` parsePackageIdentifier' "tahoe-great-black-swamp-types-0.6.0.0"
  it "finds cabal file from gitlab//philderbeast/tahoe tarball with subdir 'swamp-types/'" $ do
    ident <- getRawPackageLocationIdent' TestArchive
      { testLocation = TLUrl "https://github.com/philderbeast/tahoe-great-black-swamp-types/archive/5492e033546026b478c779fa0a4d0a7b31251188.tar.gz"
      , testSubdir = "swamp-types"
      }
    ident `shouldBe` parsePackageIdentifier' "tahoe-great-black-swamp-types-0.6.0.0"
  it "finds cabal file from github//philderbeast/tahoe tarball with subdir 'swamp/types/'" $ do
    ident <- getRawPackageLocationIdent' TestArchive
      { testLocation = TLUrl "https://github.com/philderbeast/tahoe-great-black-swamp-types/archive/739d75f273c95a2fd144fd7017fbf2fd765bdc17.tar.gz"
      , testSubdir = "swamp/types"
      }
    ident `shouldBe` parsePackageIdentifier' "tahoe-great-black-swamp-types-0.6.0.0"
  it "finds cabal file from github//glideangle/flare-timing tarball with subdir 'lang-haskell/siggy-chardust'" $ do
    ident <- getRawPackageLocationIdent' TestArchive
      { testLocation = TLUrl "https://github.com/glideangle/flare-timing/archive/333aca8c3125666ef85f41b4bb0e729a2977b122.tar.gz"
      , testSubdir = "lang-haskell/siggy-chardust"
      }
    ident `shouldBe` parsePackageIdentifier' "siggy-chardust-1.0.0"