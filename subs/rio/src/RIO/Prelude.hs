{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE NoImplicitPrelude          #-}
{-# LANGUAGE OverloadedStrings          #-}
module RIO.Prelude
  ( mapLeft
  , withLazyFile
  , fromFirst
  , mapMaybeA
  , mapMaybeM
  , forMaybeA
  , forMaybeM
  , stripCR
  , RIO (..)
  , runRIO
  , tshow
  , module X
  ) where

import           Control.Applicative  as X (Alternative, Applicative (..),
                                            liftA, liftA2, liftA3, many,
                                            optional, some, (<|>))
import           Control.Arrow        as X (first, second, (&&&), (***))
import           Control.DeepSeq      as X (NFData (..), force, ($!!))
import           Control.Monad        as X (Monad (..), MonadPlus (..), filterM,
                                            foldM, foldM_, forever, guard, join,
                                            liftM, liftM2, replicateM_, unless,
                                            when, zipWithM, zipWithM_, (<$!>),
                                            (<=<), (=<<), (>=>))
import           Control.Monad.Catch  as X (MonadThrow (..))
import           Control.Monad.Reader as X (MonadReader, MonadTrans (..),
                                            ReaderT (..), ask, asks, local)
import           Data.Bool            as X (Bool (..), not, otherwise, (&&),
                                            (||))
import           Data.ByteString      as X (ByteString)
import           Data.ByteString.Short as X (ShortByteString, toShort, fromShort)
import           Data.Char            as X (Char)
import           Data.Conduit         as X (ConduitM, runConduit, (.|))
import           Data.Data            as X (Data (..))
import           Data.Either          as X (Either (..), either, isLeft,
                                            isRight, lefts, partitionEithers,
                                            rights)
import           Data.Eq              as X (Eq (..))
import           Data.Foldable        as X (Foldable, all, and, any, asum,
                                            concat, concatMap, elem, fold,
                                            foldMap, foldl', foldr, forM_, for_,
                                            length, mapM_, msum, notElem, null,
                                            or, product, sequenceA_, sequence_,
                                            sum, toList, traverse_)
import           Data.Function        as X (const, fix, flip, id, on, ($), (&),
                                            (.))
import           Data.Functor         as X (Functor (..), void, ($>), (<$),
                                            (<$>))
import           Data.Hashable        as X (Hashable)
import           Data.HashMap.Strict  as X (HashMap)
import           Data.HashSet         as X (HashSet)
import           Data.Int             as X
import           Data.IntMap.Strict   as X (IntMap)
import           Data.IntSet          as X (IntSet)
import           Data.List            as X (break, drop, dropWhile, filter,
                                            lines, lookup, map, replicate,
                                            reverse, span, take, takeWhile,
                                            unlines, unwords, words, zip, (++))
import           Data.Map.Strict      as X (Map)
import           Data.Maybe           as X (Maybe (..), catMaybes, fromMaybe,
                                            isJust, isNothing, listToMaybe,
                                            mapMaybe, maybe, maybeToList)
import           Data.Monoid          as X (All (..), Any (..), Endo (..),
                                            First (..), Last (..), Monoid (..),
                                            Product (..), Sum (..), (<>))
import           Data.Ord             as X (Ord (..), Ordering (..), comparing)
import           Data.Set             as X (Set)
import           Data.Store           as X (Store)
import           Data.String          as X (IsString (..))
import           Data.Text            as X (Text)
import           Data.Traversable     as X (Traversable (..), for, forM)
import           Data.Vector          as X (Vector)
import           Data.Void            as X (Void, absurd)
import           Data.Word            as X
import           GHC.Generics         as X (Generic)
import           GHC.Stack            as X (HasCallStack)
import           Lens.Micro           as X (Getting, Lens', lens)
import           Lens.Micro.Mtl       as X (view)
import           Prelude              as X (Bounded (..), Double, Enum,
                                            FilePath, Float, Floating (..),
                                            Fractional (..), IO, Integer,
                                            Integral (..), Num (..), Rational,
                                            Real (..), RealFloat (..),
                                            RealFrac (..), Show, String,
                                            asTypeOf, curry, error, even,
                                            fromIntegral, fst, gcd, lcm, odd,
                                            realToFrac, seq, show, snd,
                                            subtract, uncurry, undefined, ($!),
                                            (^), (^^))
import           System.Exit          as X (ExitCode (..))
import           Text.Read            as X (Read, readMaybe)
import           UnliftIO             as X

import qualified Data.Text            as T

import qualified Data.ByteString.Lazy as BL

mapLeft :: (a1 -> a2) -> Either a1 b -> Either a2 b
mapLeft f (Left a1) = Left (f a1)
mapLeft _ (Right b) = Right b

fromFirst :: a -> First a -> a
fromFirst x = fromMaybe x . getFirst

-- | Applicative 'mapMaybe'.
mapMaybeA :: Applicative f => (a -> f (Maybe b)) -> [a] -> f [b]
mapMaybeA f = fmap catMaybes . traverse f

-- | @'forMaybeA' '==' 'flip' 'mapMaybeA'@
forMaybeA :: Applicative f => [a] -> (a -> f (Maybe b)) -> f [b]
forMaybeA = flip mapMaybeA

-- | Monadic 'mapMaybe'.
mapMaybeM :: Monad m => (a -> m (Maybe b)) -> [a] -> m [b]
mapMaybeM f = liftM catMaybes . mapM f

-- | @'forMaybeM' '==' 'flip' 'mapMaybeM'@
forMaybeM :: Monad m => [a] -> (a -> m (Maybe b)) -> m [b]
forMaybeM = flip mapMaybeM

-- | Strip trailing carriage return from Text
stripCR :: T.Text -> T.Text
stripCR t = fromMaybe t (T.stripSuffix "\r" t)

-- | Lazily get the contents of a file. Unlike 'BL.readFile', this
-- ensures that if an exception is thrown, the file handle is closed
-- immediately.
withLazyFile :: MonadUnliftIO m => FilePath -> (BL.ByteString -> m a) -> m a
withLazyFile fp inner = withBinaryFile fp ReadMode $ inner <=< liftIO . BL.hGetContents

-- | The Reader+IO monad. This is different from a 'ReaderT' because:
--
-- * It's not a transformer, it hardcodes IO for simpler usage and
-- error messages.
--
-- * Instances of typeclasses like 'MonadLogger' are implemented using
-- classes defined on the environment, instead of using an
-- underlying monad.
newtype RIO env a = RIO { unRIO :: ReaderT env IO a }
  deriving (Functor,Applicative,Monad,MonadIO,MonadReader env,MonadThrow)

runRIO :: MonadIO m => env -> RIO env a -> m a
runRIO env (RIO (ReaderT f)) = liftIO (f env)

instance MonadUnliftIO (RIO env) where
    askUnliftIO = RIO $ ReaderT $ \r ->
                  withUnliftIO $ \u ->
                  return (UnliftIO (unliftIO u . flip runReaderT r . unRIO))

tshow :: Show a => a -> Text
tshow = T.pack . show
