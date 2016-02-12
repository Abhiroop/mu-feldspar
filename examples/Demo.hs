{-# LANGUAGE QuasiQuotes #-}

module Demo where



import qualified Prelude
import Control.Monad.Trans

import Feldspar.Software
import Feldspar.Vector
import Feldspar.Option



sumInput :: Software ()
sumInput = do
    done <- initRef false
    sum  <- initRef (0 :: Data Word32)
    while (not <$> getRef done) $ do
        printf "Enter a number (0 means done): "
        n <- fget stdin
        iff (n == 0)
          (setRef done true)
          (modifyRef sum (+n))
--     abort
--     printSum sum
    s <- getRef sum
    printf "The sum of your numbers is %d.\n" (s :: Data Word32)

abort :: Software ()
abort = do
    addInclude "<stdlib.h>"
    callProc "abort" []

printSum :: Ref Word32 -> Software ()
printSum s = do
    addDefinition printSum_def
    callProc "printSum" [refArg s]

printSum_def = [cedecl|
    void printSum (typename uint32_t * s) {
        printf ("I think the sum of your numbers is %d.\n", *s);
    }
    |]

-- Compiling and running:

comp_sumInput = icompile sumInput
run_sumInput  = runCompiled sumInput



------------------------------------------------------------

fib :: Data Word32 -> Data Word32
fib n = fst $ forLoop (i2n n) (0,1) $ \_ (a,b) -> (b,a+b)

printFib :: Software ()
printFib = do
    printf "Enter a positive number: "
    n <- fget stdin
    printf "The %dth Fibonacci number is %d.\n" n (fib n)



------------------------------------------------------------

test_scProd1 = do
    n <- fget stdin
    printf "result: %.3f\n" $
      scProd (map i2n (0 ... n-1)) (map i2n (2 ... n+1))

test_scProd2 = do
    n <- fget stdin
    v1 <- store $ map i2n (0 ... n-1)
    v2 <- store $ map i2n (2 ... n+1)
    printf "result: %.3f\n" $ scProd v1 v2

map_inplace :: Software ()
map_inplace = do
    svec <- initStore (0...19)
    inplace svec $ map (*33)
    vec <- readStore svec
    printf "result: %d\n" $ sum vec



------------------------------------------------------------

-- | Array paired with its allocated size
type LArr a = (Data Length, IArr a)

-- | Index in an 'LArr'
indexL :: Syntax a => LArr (Internal a) -> Data Index -> OptionT m a
indexL (len,arr) i = guarded "indexL: out of bounds" (i<len) (arrIx arr i)

funO :: Monad m => LArr Int32 -> Data Index -> OptionT m (Data Int32)
funO arr i = do
    a <- indexL arr i
    b <- indexL arr (i+1)
    c <- indexL arr (i+2)
    d <- indexL arr (i+4)
    return (a+b+c+d)

test_option :: Software ()
test_option = do
    a <- unsafeFreezeArr =<< initArr [1..10]
    let arr = (10,a) :: LArr Int32
    i <- fget stdin
    printf "%d\n" $ fromSome $ funO arr i

test_optionM :: Software ()
test_optionM = do
    a <- unsafeFreezeArr =<< initArr [1..10]
    let arr = (10,a) :: LArr Int32
    i <- fget stdin
    caseOptionM (funO arr i)
        printf
        (printf "%d\n")

readPositive :: OptionT Software (Data Int32)
readPositive = do
    i <- lift $ fget stdin
    guarded "negative" (i>=0) (i :: Data Int32)

test_optionT = optionT printf (\_ -> return ()) $ do
    a <- unsafeFreezeArr =<< initArr [1..10]
    let arr = (10,a) :: LArr Int32
    len  <- readPositive
    sumr <- initRef (0 :: Data Int32)
    for (0, 1, Excl len) $ \i -> do
        lift $ printf "reading index %d\n" i
        x <- indexL arr (i2n i)
        modifyRefD sumr (+x)
    s <- unsafeFreezeRef sumr
    lift $ printf "%d" (s :: Data Int32)

------------------------------------------------------------

testAll = do
    compareCompiled sumInput     (runIO sumInput) (Prelude.unlines $ Prelude.map show $ Prelude.reverse [0..20])
    compareCompiled printFib     (runIO printFib)     "7\n"
    compareCompiled test_scProd1 (runIO test_scProd1) "20\n"
    compareCompiled test_scProd2 (runIO test_scProd2) "20\n"
    compareCompiled map_inplace  (runIO map_inplace)  ""
    compareCompiled test_option  (runIO test_option)  "5\n"
    compareCompiled test_option  (runIO test_option)  "6\n"
    compareCompiled test_optionM (runIO test_option)  "5\n"
    compareCompiled test_optionM (runIO test_optionM) "6\n"
    compareCompiled test_optionT (runIO test_optionT) "10\n"

