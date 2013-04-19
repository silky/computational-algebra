module Main (module Algebra.Algorithms.Groebner.Monomorphic, module Algebra.Ring.Polynomial
            {- , module Algebra.Ring.Polynomial.Parser-} , module Algebra.Ring.Polynomial.Monomorphic
            , module Data.Ratio, module Main, module Algebra.Internal
            ) where
import Algebra.Algorithms.Groebner.Monomorphic
import Algebra.Internal
import Algebra.Ring.Polynomial                 (Grevlex (..), Grlex (..),
                                                Lex (..), ProductOrder (..),
                                                WeightOrder (..),
                                                WeightProxy (..),
                                                eliminationOrder,
                                                weightedEliminationOrder)
import Algebra.Ring.Polynomial.Monomorphic
-- import           Algebra.Ring.Polynomial.Parser
import           Data.Ratio
import qualified Numeric.Algebra as NA

var_x, var_y, var_z, var_t, var_u :: Variable
[var_c, var_s, var_x, var_y, var_z, var_t, var_u] = map (flip Variable Nothing) "csxyztu"

x, y, z, t, u :: Polynomial Rational
[c, s, x, y, z, t, u] = map injectVar [var_c, var_s, var_x, var_y, var_z, var_t, var_u]

(.+), (.*), (.-) :: Polynomial Rational -> Polynomial Rational -> Polynomial Rational
(.+) = (NA.+)
(.*) = (NA.*)
(.-) = (NA.-)

infixl 6 .+, .-
infixl 7 .*

(^^^) :: Polynomial Rational -> NA.Natural -> Polynomial Rational
(^^^) = NA.pow

fromRight :: Either t t1 -> t1
fromRight (Right a) = a

{-
parse :: String -> Polynomial Rational
parse = fromRight . parsePolyn
-}

main :: IO ()
main = print $ eliminate [var_s, var_c] [x-c^3, y-s^3, c^2+s^2-1]