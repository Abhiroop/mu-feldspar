{-# LANGUAGE DataKinds #-}
{-# LANGUAGE UndecidableInstances #-}

-- | Typed binary tree structures

module Data.TypedStruct where



import Control.Monad.Identity
import Data.Proxy



--------------------------------------------------------------------------------
-- * Representation
--------------------------------------------------------------------------------

-- | Typed binary tree structure
data Struct pred con a
  where
    Single :: pred a => con a -> Struct pred con a
    Two    :: Struct pred con a -> Struct pred con b -> Struct pred con (a,b)
  -- The constraint `NoPair a` is required to make functions like
  -- `extractSingle` and `zipStruct` total. Unfortunately, the completeness
  -- checker (-fwarn-incomplete-patterns) is unable to verify that these
  -- functions are total, but it can be verified by trying to add another
  -- non-overlapping pattern. This leads to a type error.
  --
  -- `extractSingle` uses a trick that indeed makes the completeness checker
  -- happy. The idea is to call `impossible` for the constructor that ought not
  -- to appear. We can convince ourselves once and for all that `impossible` is
  -- always safe to insert, because its type prevents it from ever being used.
  -- Unfortunately, "the trick" doesn't scale very well. We would need to
  -- introduce more helper types and impossible functions to cover the other
  -- cases in this module.

-- | Representation of the structure of a 'Struct'
type StructRep pred = Struct pred Proxy

-- | Structured types
class StructType_ pred a
  where
    structRep :: StructRep pred a
  -- Not exported since we want a closed class

instance pred a => StructType_ pred a
  where
    structRep = Single Proxy

instance {-# OVERLAPS #-} (StructType_ p a, StructType_ p b) =>
    StructType_ p (a,b)
  where
    structRep = Two structRep structRep

-- | Structured types
class    StructType_ pred a => StructType pred a
instance StructType_ pred a => StructType pred a
  -- TODO Needed?

-- | Create a 'Struct' from a structured value
toStruct :: forall p a . StructType p a => a -> Struct p Identity a
toStruct = go (structRep :: StructRep p a) . Identity
  where
    go :: StructRep p b -> Identity b -> Struct p Identity b
    go (Single _) i = Single i
    go (Two ra rb) (Identity (a,b)) =
        Two (go ra (Identity a)) (go rb (Identity b))



--------------------------------------------------------------------------------
-- * Operations
--------------------------------------------------------------------------------

-- | Extract the value of a 'Single'
extractSingle :: pred a => Struct pred c a -> c a
extractSingle (Single a) = a

-- | Map over a 'Struct'
mapStruct :: forall pred c1 c2 b
    .  (forall a . pred a => c1 a -> c2 a)
    -> Struct pred c1 b
    -> Struct pred c2 b
mapStruct f = go
  where
    go :: Struct pred c1 a -> Struct pred c2 a
    go (Single a) = Single (f a)
    go (Two a b)  = Two (go a) (go b)

-- | Monadic map over a 'Struct'
mapStructA :: forall m pred c1 c2 b . Applicative m
    => (forall a . pred a => c1 a -> m (c2 a))
    -> Struct pred c1 b -> m (Struct pred c2 b)
mapStructA f = go
  where
    go :: Struct pred c1 a -> m (Struct pred c2 a)
    go (Single a) = Single <$> (f a)
    go (Two a b)  = Two <$> go a <*> go b

-- | Map over a 'Struct'
mapStructA_ :: forall m pred cont b . Applicative m =>
    (forall a . pred a => cont a -> m ()) -> Struct pred cont b -> m ()
mapStructA_ f = go
  where
    go :: Struct pred cont a -> m ()
    go (Single a) = f a
    go (Two a b)  = go a *> go b

-- mapStructM_ :: forall m pred cont b . Monad m =>
--     (forall a . pred a => cont a -> m ()) -> Struct pred cont b -> m ()
-- mapStructM_ f = sequence_ . listStruct f
  -- This doesn't work for some reason, only if `pred` is constrained to a
  -- concrete type. (On the other hand, using `listStruct` is probably less
  -- efficient due to the use of `++`.)

-- | Fold a 'Struct' to a list
listStruct :: forall pred cont b c .
    (forall y . pred y => cont y -> c) -> Struct pred cont b -> [c]
listStruct f = go
  where
    go :: Struct pred cont a -> [c]
    go (Single a) = [f a]
    go (Two a b)  = go a ++ go b

-- | Zip two 'Struct's
zipStruct :: forall pred c1 c2 c3 b
    . (forall a . pred a => c1 a -> c2 a -> c3 a)
    -> Struct pred c1 b
    -> Struct pred c2 b
    -> Struct pred c3 b
zipStruct f = go
  where
    go :: Struct pred c1 a -> Struct pred c2 a -> Struct pred c3 a
    go (Single a) (Single b) = Single (f a b)
    go (Two a b) (Two c d)   = Two (go a c) (go b d)

-- | Zip two 'Struct's to a list
zipListStruct :: forall pred c1 c2 b r
    . (forall a . pred a => c1 a -> c2 a -> r)
    -> Struct pred c1 b
    -> Struct pred c2 b
    -> [r]
zipListStruct f = go
  where
    go :: Struct pred c1 a -> Struct pred c2 a -> [r]
    go (Single a) (Single b) = [f a b]
    go (Two a b) (Two c d)   = go a c ++ go b d

-- | Compare two 'Struct's using a function that compares the 'Single' elements.
-- If the structures don't match, 'False' is returned.
compareStruct :: forall pred c1 c2 c d
    . (forall a b . (pred a, pred b) => c1 a -> c2 b -> Bool)
    -> Struct pred c1 c
    -> Struct pred c2 d
    -> Bool
compareStruct f = go
  where
    go :: Struct pred c1 a -> Struct pred c2 b -> Bool
    go (Single a) (Single b) = f a b
    go (Two a b) (Two c d)   = go a c && go b d

-- | Lift a function operating on containers @con@ to a function operating on
-- 'Struct's.
liftStruct :: (pred a, pred b) =>
    (con a -> con b) -> Struct pred con a -> Struct pred con b
liftStruct f (Single a) = Single (f a)

-- | Lift a function operating on containers @con@ to a function operating on
-- 'Struct's.
liftStruct2 :: (pred a, pred b, pred c)
    => (con a -> con b -> con c)
    -> Struct pred con a -> Struct pred con b -> Struct pred con c
liftStruct2 f (Single a) (Single b) = Single (f a b)

