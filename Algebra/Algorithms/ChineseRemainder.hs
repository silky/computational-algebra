{-# LANGUAGE ViewPatterns #-}
module Algebra.Algorithms.ChineseRemainder where

import Data.List                (findIndices)
import Numeric.Domain.Euclidean (euclid)
import Numeric.Domain.Euclidean (chineseRemainder)
import Numeric.Field.Fraction

recoverRat :: Integer                    -- ^ Bound for numerator
           -> Integer                    -- ^ modulus
           -> Integer                    -- ^ integer corresponds to the rational number.
           -> Maybe (Fraction Integer)   -- ^ recovered rational number
recoverRat (abs -> k) m g =
  let ps = euclid m g
      ixs = findIndices (\(rj, _, _) -> abs rj < k) ps
  in if null ixs
     then Nothing
     else
       let j = last ixs
           (r, _, t)   = ps !! j
           (r0,_ , t0) = ps !! (j + 1)
           q | j == 0  = 0
             | otherwise = head $ filter (\v -> r0 - v*r < k && k <= r0 - (v-1)*r) [1..]
           (r', t') = (r0 - q * r, t0 - q * t)
       in if gcd r t == 1
          then Just (r % t)
          else if gcd r' t' == 1 && abs t' <= m `quot` k
               then Just (r' % t')
               else Nothing

rationalChineseRemainder :: Integer -> [(Integer, Integer)] -> Maybe (Fraction Integer)
rationalChineseRemainder k mvs =
  let m = product $ map fst mvs
      g = chineseRemainder mvs
  in recoverRat k m g

