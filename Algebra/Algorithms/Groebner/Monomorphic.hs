{-# LANGUAGE ConstraintKinds, FlexibleInstances, GADTs, PolyKinds #-}
{-# LANGUAGE RecordWildCards, ScopedTypeVariables, TypeFamilies   #-}
{-# LANGUAGE TypeOperators                                        #-}
-- | Monomorphic interface for Groenber basis.
module Algebra.Algorithms.Groebner.Monomorphic
    (
    -- * Polynomial division
      divModPolynomial, divPolynomial, modPolynomial
    , divModPolynomialWith, divPolynomialWith, modPolynomialWith
    -- * Groebner basis
    , calcGroebnerBasis, calcGroebnerBasisWith
    -- * Ideal operations
    , isIdealMember, intersection, thEliminationIdeal, eliminate
    , quotIdeal, quotByPrincipalIdeal
    , saturationIdeal, saturationByPrincipalIdeal
    -- * Re-exports
    , Lex(..), Revlex(..), Grlex(..), Grevlex(..), IsOrder, IsMonomialOrder
    ) where
import qualified Algebra.Algorithms.Groebner         as Gr
import           Algebra.Internal
import           Algebra.Ring.Noetherian
import           Algebra.Ring.Polynomial             (Grevlex (..), Grlex (..),
                                                      IsMonomialOrder, IsOrder,
                                                      Lex (..), Revlex (..),
                                                      orderedBy)
import qualified Algebra.Ring.Polynomial             as Poly
import           Algebra.Ring.Polynomial.Monomorphic
import           Control.Arrow
import           Data.List
import qualified Data.Map                            as M
import           Numeric.Algebra
import           Prelude                             hiding (Num (..))

type Groebnerable r = (Eq r, Field r, NoetherianRing r)

intersection :: forall r. (Eq r, Field r, NoetherianRing r)
             => [[Polynomial r]] -> [Polynomial r]
intersection ps =
  let vars = nub $ sort $ concatMap (concatMap buildVarsList) ps
      dim  = length vars
  in case promote dim of
       Monomorphic sdim ->
         case singInstance sdim of
           SingInstance ->
             case promote ps :: Monomorphic (Vector [Polynomial r]) of
               Monomorphic vec ->
                 let slen = sLengthV vec
                 in case singInstance slen of
                      SingInstance ->
                        let ids = mapV (toIdeal . map (flip orderedBy Lex . Poly.polynomial . M.mapKeys (Poly.OrderedMonomial . Poly.fromList sdim . encodeMonomList vars) . unPolynomial)) vec
                        in case singInstance (slen %+ sdim) of
                             SingInstance -> demoteComposed $ Gr.intersection ids

freshVar :: [Polynomial r] -> Variable
freshVar ps =
    case maximum $ concatMap buildVarsList ps of
      Variable c Nothing  -> Variable c (Just 1)
      Variable c (Just n) -> Variable c (Just $ n + 1)

saturationByPrincipalIdeal :: (Groebnerable r)
                           => [Polynomial r] -> Polynomial r -> [Polynomial r]
saturationByPrincipalIdeal j g =
  let t = freshVar (g : j)
  in eliminate [t] $ (one - g * injectVar t) : j

saturationIdeal :: Groebnerable r => [Polynomial r] -> [Polynomial r] -> [Polynomial r]
saturationIdeal i g = intersection $ map (i `saturationByPrincipalIdeal`) g

quotByPrincipalIdeal :: Groebnerable r => [Polynomial r] -> Polynomial r -> [Polynomial r]
quotByPrincipalIdeal i g =
  map (snd . head . flip (divPolynomialWith Lex) [g]) $ intersection [i, [g]]

quotIdeal :: Groebnerable r => [Polynomial r] -> [Polynomial r] -> [Polynomial r]
quotIdeal i g = intersection $ map (i `quotByPrincipalIdeal`) g

divModPolynomial :: Groebnerable r
                 => Polynomial r -> [Polynomial r] -> ([(Polynomial r, Polynomial r)], Polynomial r)
divModPolynomial = divModPolynomialWith Grevlex

divModPolynomialWith :: forall ord r. (IsMonomialOrder ord, Groebnerable r)
                     => ord -> Polynomial r -> [Polynomial r]
                     -> ([(Polynomial r, Polynomial r)], Polynomial r)
divModPolynomialWith _ f gs =
  case promoteList (f:gs) :: Monomorphic ([] :.: Poly.OrderedPolynomial r ord) of
    Monomorphic (Comp (f' : gs')) ->
      let sn = Poly.sDegree f'
      in case singInstance sn of
           SingInstance ->
             let (q, r) = Gr.divModPolynomial f' gs'
             in (map (renameVars vars . polyn . demote' *** polyn . demote') q, polyn $ demote' r)
  where
    vars = nub $ sort $ concatMap buildVarsList (f:gs)

divPolynomial :: Groebnerable r => Polynomial r -> [Polynomial r] -> [(Polynomial r, Polynomial r)]
divPolynomial = (fst .) . divModPolynomial

modPolynomial :: Groebnerable r => Polynomial r -> [Polynomial r] -> Polynomial r
modPolynomial = (snd .) . divModPolynomial

divPolynomialWith :: Groebnerable r => IsMonomialOrder ord => ord -> Polynomial r -> [Polynomial r] -> [(Polynomial r, Polynomial r)]
divPolynomialWith ord = (fst .) . divModPolynomialWith ord

modPolynomialWith :: (Groebnerable r, IsMonomialOrder ord)
                  => ord -> Polynomial r -> [Polynomial r] -> Polynomial r
modPolynomialWith ord = (snd .) . divModPolynomialWith ord

calcGroebnerBasis :: Groebnerable r => [Polynomial r] -> [Polynomial r]
calcGroebnerBasis = calcGroebnerBasisWith Grevlex

calcGroebnerBasisWith :: forall ord r. (Groebnerable r, IsMonomialOrder ord)
                      => ord -> [Polynomial r] -> [Polynomial r]
calcGroebnerBasisWith _ ps | any (== zero) ps = []
calcGroebnerBasisWith ord j =
  case uniformlyPromote j :: Monomorphic (Ideal :.: Poly.OrderedPolynomial r ord) of
    Monomorphic (Comp ideal) ->
      case ideal of
        Ideal vec ->
          case singInstance (Poly.sDegree (head $ toList vec)) of
            SingInstance -> map (renameVars vars . polyn . demote . Monomorphic) $ Gr.calcGroebnerBasisWith ord ideal
  where
    vars = nub $ sort $ concatMap buildVarsList j

isIdealMember :: forall r. Groebnerable r => Polynomial r -> [Polynomial r] -> Bool
isIdealMember f ideal =
  case promoteList (f:ideal) :: Monomorphic ([] :.: Poly.Polynomial r) of
    Monomorphic (Comp (f':ideal')) ->
      case singInstance (Poly.sDegree f') of
        SingInstance -> Gr.isIdealMember f' (toIdeal ideal')
    _ -> error "impossible happend!"

-- | Computes the ideal with specified variables eliminated.
eliminate :: forall r. Groebnerable r => [Variable] -> [Polynomial r] -> [Polynomial r]
eliminate elvs j =
  case promoteListWithVarOrder (els ++ rest) j :: Monomorphic ([] :.: Poly.OrderedPolynomial r Poly.Lex) of
    Monomorphic (Comp fs) ->
      case promote k of
        Monomorphic sk ->
          let sdim = Poly.sDegree $ head fs
              newDim = sMax sk sdim
          in case singInstance sdim of
               SingInstance ->
                 case propToClassLeq $ maxLeqR sk sdim of
                   LeqInstance ->
                     case singInstance newDim of
                       SingInstance ->
                         let fs'  = map ((flip Poly.orderedBy Poly.Lex) . Poly.scastPolynomial newDim) fs
                         in case propToBoolLeq $ maxLeqL sk sdim of
                              LeqTrueInstance ->
                                case singInstance (newDim %- sk) of
                                  SingInstance ->
                                    map (renameVars rest) $ demoteComposed $ sk `Gr.thEliminationIdeal` toIdeal fs'
  where
    vars = nub $ sort $ concatMap buildVarsList j
    (els, rest) = partition (`elem` elvs) vars
    k = length els

-- | Computes nth elimination ideal.
thEliminationIdeal :: Groebnerable r => Int -> [Polynomial r] -> [Polynomial r]
thEliminationIdeal k j = eliminate (take k vars) j
  where
    vars = nub $ sort $ concatMap buildVarsList j