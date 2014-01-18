{-----------------------------------------------------------------------------
    reactive-banana
------------------------------------------------------------------------------}
{-# LANGUAGE RecursiveDo #-}
module Reactive.Banana.Prim.Evaluation where

import qualified Control.Exception as Strict (evaluate)
import           Data.Monoid

import qualified Reactive.Banana.Prim.Dependencies as Deps
import           Reactive.Banana.Prim.Plumbing
import           Reactive.Banana.Prim.Types

{-----------------------------------------------------------------------------
    Graph evaluation
------------------------------------------------------------------------------}
-- | Evaluate all the pulses in the graph,
-- Rebuild the graph as necessary and update the latch values.
step :: Inputs -> Step
step (pulse1, roots) state1 = {-# SCC step #-} mdo
    let graph1 = nGraph state1
        latch1 = nLatchValues state1

    ((_, latchUpdates, output), state2)
            <- runBuildIO state1
            $  runEvalP pulse1
            $  evaluatePulses graph1 roots
    
    let graph2 = nGraph state2
        latch2 = appEndo latchUpdates $ nLatchValues state2
        state3 = Network graph2 latch2

    -- make sure that the latch values are in WHNF
    Strict.evaluate latch2
    return (output latch2, state3)

-- | Update all pulses in the graph, starting from a given set of nodes
evaluatePulses :: Graph -> [SomeNode] -> EvalP ()
evaluatePulses graph = Deps.traverseDependencies evaluatePulse (grDeps graph)
    where
    evaluatePulse (P p) = evaluateP p
    evaluatePulse (L l) = evaluateL l >>= rememberLatchUpdate >> return Deps.Done
    evaluatePulse (O o) = evaluateO o >>= rememberOutput      >> return Deps.Done

-- TODO: Optimize output query.
-- Instead of polling each output whether it has fired,
-- obtain this information from the graph traversal instead.
-- However, in this case, order of declaration, not the order of firing.
