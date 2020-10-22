module Game.Hidato(Hidato, fromList, solveHidato, genHidato) where
import qualified Data.IntMap as IM
import qualified Data.Set as DS
import System.Random(StdGen)
import Data.List(sort, groupBy)
import Game.Table(stringToTable, tableToString, Cell, InfoCell, MarkedCell, cellDistance, Direction, getNeighbours, Shape, genShape)

--A Hidato table, ocupied cells with numbers and free cells to be set. 
data Hidato = Hid { mcells :: IM.IntMap Cell, ucells :: DS.Set Cell, current :: MarkedCell, next :: Maybe MarkedCell }

--Creates a Hidato from a List with cell's cordenates and his possible numbers
fromList :: [(InfoCell)] -> Hidato
fromList cells =
    let
        mcells = IM.fromList [(v, c) | (Just v, c) <- cells]
        ucells = DS.fromList [c | (Nothing, c) <- cells]
        Just current = IM.lookupMin mcells
        next = IM.lookupGT (fst current) mcells
    in Hid mcells ucells current next

-- Just move on to the next cell and mark it, return all sub-solutions if move was legal
markCell :: Hidato -> Int -> Cell -> [Hidato]
markCell (Hid mcells ucells current (Just next@(nextp, nextc))) p c 
    | next == mcell                      = solveHidato $ Hid mcells ucells mcell (IM.lookupGT p mcells)
    | cellDistance nextc c > (nextp - p) = []
    | DS.member c ucells                 = solveHidato $ Hid (IM.insert p c mcells) (DS.delete c ucells) mcell (Just next)
    | otherwise                          = []
    where mcell = (p, c)

--Solver function, a trivial backtrack thats travel all posibles paths
solveHidato :: Hidato -> [Hidato]
solveHidato h@(Hid _ _ _ Nothing) = [h]
solveHidato h = concatMap (markCell h (p + 1)) (getNeighbours minBound cell)
    where (p, cell) = current h

--Check if hidato has unique solution
uniqueSolution :: Hidato -> Bool
uniqueSolution h = 
    case solveHidato h of
        [] -> error $ "This hidato has no solution:\n" ++ show h
        [_] -> True
        _   -> False

--Try hide une cell, if we lose unique condition, return the same hidato
hideCell :: Hidato -> Int -> Hidato
hideCell hid@(Hid mcells ucells start end) pos
    | uniqueSolution nhid = nhid
    | otherwise           = hid
    where
        Just cell = IM.lookup pos mcells
        nhid = Hid (IM.delete pos mcells) (DS.insert cell ucells) start end

--Generator funtion, starting with a fully solved hidato, try hide each cell only if unique condition holds
genHidato :: StdGen -> Shape -> Hidato
genHidato gen shape = foldl hideCell hid [(s + 1) .. (e - 1)]
    where
        table = genShape gen shape
        hid = fromList table
        s = fst . current $ hid
        Just (e, _) = IM.lookupMax . mcells $ hid

--Making Hidato friend of class Read for set custom read
instance Read Hidato where
    readsPrec _ s = 
        let 
            table = stringToTable s
            readrow row i = [(readCell c, (i, j)) | (c, j) <- zip row [1..], c /= "-"]
            cells = concat (zipWith readrow table [1..])
        in
            [(fromList cells, "")]
        where
            readCell :: String -> Maybe Int
            readCell "+" = Nothing
            readCell v   = Just (read v)

--Making Hidato friend of class Show for set custom show
instance Show Hidato where
    show (Hid mcells ucells start end) = 
        let
            mcells_list = map (\(p, c) -> (c, Just p)) (IM.toList mcells)
            ucells_list = map (\c -> (c, Nothing)) (DS.toList ucells)
            all_cells = sort $ mcells_list ++ ucells_list
            table = groupBy (\(a,_) (b,_) -> fst a == fst b) all_cells
        in 
            tableToString $ map (fill_from 1) table
        where
            fill_from _ [] = []
            fill_from i l@((c, p) : xs)
                | i < snd c     = "-" : fill_from (i + 1) l
                | otherwise = (putCell p) : fill_from (i + 1) xs

            putCell Nothing = "+"
            putCell (Just p) = show p

