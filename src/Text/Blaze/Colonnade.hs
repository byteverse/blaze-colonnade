{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}

{- | Build HTML tables using @blaze-html@ and @colonnade@. The bottom
  of this page has a tutorial that walks through a full example,
  illustrating how to meet typical needs with this library. It is
  recommended that users read the documentation for @colonnade@ first,
  since this library builds on the abstractions introduced there.
  A concise example of this library\'s use:

>>> :set -XOverloadedStrings
>>> :module + Colonnade Text.Blaze.Html Text.Blaze.Colonnade
>>> let col = headed "Grade" (toHtml . fst) <> headed "Letter" (toHtml . snd)
>>> let rows = [("90-100",'A'),("80-89",'B'),("70-79",'C')]
>>> printVeryCompactHtml (encodeHtmlTable mempty col rows)
<table>
    <thead>
        <tr><th>Grade</th><th>Letter</th></tr>
    </thead>
    <tbody>
        <tr><td>90-100</td><td>A</td></tr>
        <tr><td>80-89</td><td>B</td></tr>
        <tr><td>70-79</td><td>C</td></tr>
    </tbody>
</table>
-}
module Text.Blaze.Colonnade
  ( -- * Apply
    encodeCappedCellTable
  , encodeHtmlTable
  , encodeCellTable
  , encodeTable
  , encodeCappedTable

    -- * Cell
    -- $build
  , Cell (..)
  , charCell
  , htmlCell
  , stringCell
  , textCell
  , lazyTextCell
  , builderCell
  , htmlFromCell

    -- * Interactive
  , printCompactHtml
  , printVeryCompactHtml

    -- * Tutorial
    -- $setup

    -- * Discussion
    -- $discussion
  ) where

import Colonnade (Colonnade, Cornice, Fascia, Headed)
import qualified Colonnade.Encode as E
import Control.Monad
import Data.Char (isSpace)
import Data.Foldable
import qualified Data.List as List
import Data.Maybe (listToMaybe)
import Data.String (IsString (..))
import Data.Text (Text)
import qualified Data.Text.Lazy as LText
import qualified Data.Text.Lazy.Builder as TBuilder
import Text.Blaze (Attribute, (!))
import Text.Blaze.Html (Html, toHtml)
import qualified Text.Blaze.Html.Renderer.Pretty as Pretty
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as HA

{- $setup
We start with a few necessary imports and some example data
types:

>>> :set -XOverloadedStrings
>>> import Data.Monoid (mconcat,(<>))
>>> import Data.Char (toLower)
>>> import Data.Profunctor (Profunctor(lmap))
>>> import Colonnade (Colonnade,Headed,Headless,headed,cap,Fascia(..))
>>> import Text.Blaze.Html (Html, toHtml, toValue)
>>> import qualified Text.Blaze.Html5 as H
>>> data Department = Management | Sales | Engineering deriving (Show,Eq)
>>> data Employee = Employee { name :: String, department :: Department, age :: Int }

We define some employees that we will display in a table:

>>> :{
let employees =
      [ Employee "Thaddeus" Sales 34
      , Employee "Lucia" Engineering 33
      , Employee "Pranav" Management 57
      ]
:}

Let's build a table that displays the name and the age
of an employee. Additionally, we will emphasize the names of
engineers using a @\<strong\>@ tag.

>>> :{
let tableEmpA :: Colonnade Headed Employee Html
    tableEmpA = mconcat
      [ headed "Name" $ \emp -> case department emp of
          Engineering -> H.strong (toHtml (name emp))
          _ -> toHtml (name emp)
      , headed "Age" (toHtml . show . age)
      ]
:}

The type signature of @tableEmpA@ is inferrable but is written
out for clarity in this example. Additionally, note that the first
argument to 'headed' is of type 'Html', so @OverloadedStrings@ is
necessary for the above example to compile. To avoid using this extension,
it is possible to instead use 'toHtml' to convert a 'String' to 'Html'.
Let\'s continue:

>>> let customAttrs = HA.class_ "stylish-table" <> HA.id "main-table"
>>> printCompactHtml (encodeHtmlTable customAttrs tableEmpA employees)
<table class="stylish-table" id="main-table">
    <thead>
        <tr>
            <th>Name</th>
            <th>Age</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>Thaddeus</td>
            <td>34</td>
        </tr>
        <tr>
            <td><strong>Lucia</strong></td>
            <td>33</td>
        </tr>
        <tr>
            <td>Pranav</td>
            <td>57</td>
        </tr>
    </tbody>
</table>

Excellent. As expected, Lucia\'s name is wrapped in a @\<strong\>@ tag
since she is an engineer.

One limitation of using 'Html' as the content
type of a 'Colonnade' is that we are unable to add attributes to
the @\<td\>@ and @\<th\>@ elements. This library provides the 'Cell' type
to work around this problem. A 'Cell' is just 'Html' content and a set
of attributes to be applied to its parent @<th>@ or @<td>@. To illustrate
how its use, another employee table will be built. This table will
contain a single column indicating the department of each employ. Each
cell will be assigned a class name based on the department. To start off,
let\'s build a table that encodes departments:

>>> :{
let tableDept :: Colonnade Headed Department Cell
    tableDept = mconcat
      [ headed "Dept." $ \d -> Cell
          (HA.class_ (toValue (map toLower (show d))))
          (toHtml (show d))
      ]
:}

Again, @OverloadedStrings@ plays a role, this time allowing the
literal @"Dept."@ to be accepted as a value of type 'Cell'. To avoid
this extension, 'stringCell' could be used to upcast the 'String'.
To try out our 'Colonnade' on a list of departments, we need to use
'encodeCellTable' instead of 'encodeHtmlTable':

>>> let twoDepts = [Sales,Management]
>>> printVeryCompactHtml (encodeCellTable customAttrs tableDept twoDepts)
<table class="stylish-table" id="main-table">
    <thead>
        <tr><th>Dept.</th></tr>
    </thead>
    <tbody>
        <tr><td class="sales">Sales</td></tr>
        <tr><td class="management">Management</td></tr>
    </tbody>
</table>

The attributes on the @\<td\>@ elements show up as they are expected to.
Now, we take advantage of the @Profunctor@ instance of 'Colonnade' to allow
this to work on @Employee@\'s instead:

>>> :t lmap
lmap :: Profunctor p => (a -> b) -> p b c -> p a c
>>> let tableEmpB = lmap department tableDept
>>> :t tableEmpB
tableEmpB :: Colonnade Headed Employee Cell
>>> printVeryCompactHtml (encodeCellTable customAttrs tableEmpB employees)
<table class="stylish-table" id="main-table">
    <thead>
        <tr><th>Dept.</th></tr>
    </thead>
    <tbody>
        <tr><td class="sales">Sales</td></tr>
        <tr><td class="engineering">Engineering</td></tr>
        <tr><td class="management">Management</td></tr>
    </tbody>
</table>

This table shows the department of each of our three employees, additionally
making a lowercased version of the department into a class name for the @\<td\>@.
This table is nice for illustrative purposes, but it does not provide all the
information that we have about the employees. If we combine it with the
earlier table we wrote, we can present everything in the table. One small
roadblock is that the types of @tableEmpA@ and @tableEmpB@ do not match, which
prevents a straightforward monoidal append:

>>> :t tableEmpA
tableEmpA :: Colonnade Headed Employee Html
>>> :t tableEmpB
tableEmpB :: Colonnade Headed Employee Cell

We can upcast the content type with 'fmap'.
Monoidal append is then well-typed, and the resulting 'Colonnade'
can be applied to the employees:

>>> let tableEmpC = fmap htmlCell tableEmpA <> tableEmpB
>>> :t tableEmpC
tableEmpC :: Colonnade Headed Employee Cell
>>> printCompactHtml (encodeCellTable customAttrs tableEmpC employees)
<table class="stylish-table" id="main-table">
    <thead>
        <tr>
            <th>Name</th>
            <th>Age</th>
            <th>Dept.</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>Thaddeus</td>
            <td>34</td>
            <td class="sales">Sales</td>
        </tr>
        <tr>
            <td><strong>Lucia</strong></td>
            <td>33</td>
            <td class="engineering">Engineering</td>
        </tr>
        <tr>
            <td>Pranav</td>
            <td>57</td>
            <td class="management">Management</td>
        </tr>
    </tbody>
</table>
-}

{- $build

The 'Cell' type is used to build a 'Colonnade' that
has 'Html' content inside table cells and may optionally
have attributes added to the @\<td\>@ or @\<th\>@ elements
that wrap this HTML content.
-}

{- | The attributes that will be applied to a @\<td\>@ and
  the HTML content that will go inside it. When using
  this type, remember that 'Attribute', defined in @blaze-markup@,
  is actually a collection of attributes, not a single attribute.
-}
data Cell = Cell
  { cellAttribute :: !Attribute
  , cellHtml :: !Html
  }

instance IsString Cell where
  fromString = stringCell

instance Semigroup Cell where
  (Cell a1 c1) <> (Cell a2 c2) = Cell (a1 <> a2) (c1 <> c2)

instance Monoid Cell where
  mempty = Cell mempty mempty
  mappend = (<>)

-- | Create a 'Cell' from a 'Widget'
htmlCell :: Html -> Cell
htmlCell = Cell mempty

-- | Create a 'Cell' from a 'String'
stringCell :: String -> Cell
stringCell = htmlCell . fromString

-- | Create a 'Cell' from a 'Char'
charCell :: Char -> Cell
charCell = stringCell . pure

-- | Create a 'Cell' from a 'Text'
textCell :: Text -> Cell
textCell = htmlCell . toHtml

-- | Create a 'Cell' from a lazy text
lazyTextCell :: LText.Text -> Cell
lazyTextCell = textCell . LText.toStrict

-- | Create a 'Cell' from a text builder
builderCell :: TBuilder.Builder -> Cell
builderCell = lazyTextCell . TBuilder.toLazyText

{- | Encode a table. This handles a very general case and
  is seldom needed by users. One of the arguments provided is
  used to add attributes to the generated @\<tr\>@ elements.
-}
encodeTable ::
  forall h f a c.
  (Foldable f, E.Headedness h) =>
  -- | Attributes of @\<thead\>@ and its @\<tr\>@, pass 'Nothing' to omit @\<thead\>@
  h (Attribute, Attribute) ->
  -- | Attributes of @\<tbody\>@ element
  Attribute ->
  -- | Attributes of each @\<tr\>@ element
  (a -> Attribute) ->
  -- | Wrap content and convert to 'Html'
  ((Html -> Html) -> c -> Html) ->
  -- | Attributes of @\<table\>@ element
  Attribute ->
  -- | How to encode data as a row
  Colonnade h a c ->
  -- | Collection of data
  f a ->
  Html
encodeTable mtheadAttrs tbodyAttrs trAttrs wrapContent tableAttrs colonnade xs =
  H.table ! tableAttrs $ do
    case E.headednessExtractForall of
      Nothing -> return mempty
      Just extractForall -> do
        let (theadAttrs, theadTrAttrs) = extract mtheadAttrs
        H.thead ! theadAttrs $ H.tr ! theadTrAttrs $ do
          -- E.headerMonoidalGeneral colonnade (wrapContent H.th)
          foldlMapM' (wrapContent H.th . extract . E.oneColonnadeHead) (E.getColonnade colonnade)
       where
        extract :: forall y. h y -> y
        extract = E.runExtractForall extractForall
    encodeBody trAttrs wrapContent tbodyAttrs colonnade xs

foldlMapM' :: forall g b a m. (Foldable g, Monoid b, Monad m) => (a -> m b) -> g a -> m b
foldlMapM' f xs = foldr f' pure xs mempty
 where
  f' :: a -> (b -> m b) -> b -> m b
  f' x k bl = do
    br <- f x
    let !b = mappend bl br
    k b

{- | Encode a table with tiered header rows.
>>> let cor = mconcat [cap "Personal" (fmap htmlCell tableEmpA), cap "Work" tableEmpB]
>>> let fascia = FasciaCap (HA.class_ "category") (FasciaBase (HA.class_ "subcategory"))
>>> printCompactHtml (encodeCappedCellTable mempty fascia cor [head employees])
<table>
    <thead>
        <tr class="category">
            <th colspan="2">Personal</th>
            <th colspan="1">Work</th>
        </tr>
        <tr class="subcategory">
            <th colspan="1">Name</th>
            <th colspan="1">Age</th>
            <th colspan="1">Dept.</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>Thaddeus</td>
            <td>34</td>
            <td class="sales">Sales</td>
        </tr>
    </tbody>
</table>
-}
encodeCappedCellTable ::
  (Foldable f) =>
  -- | Attributes of @\<table\>@ element
  Attribute ->
  -- | Attributes for @\<tr\>@ elements in the @\<thead\>@
  Fascia p Attribute ->
  Cornice Headed p a Cell ->
  -- | Collection of data
  f a ->
  Html
encodeCappedCellTable = encodeCappedTable mempty mempty (const mempty) htmlFromCell

{- | Encode a table with tiered header rows. This is the most general function
  in this library for encoding a 'Cornice'.
-}
encodeCappedTable ::
  (Foldable f) =>
  -- | Attributes of @\<thead\>@
  Attribute ->
  -- | Attributes of @\<tbody\>@ element
  Attribute ->
  -- | Attributes of each @\<tr\>@ element in the @\<tbody\>@
  (a -> Attribute) ->
  -- | Wrap content and convert to 'Html'
  ((Html -> Html) -> c -> Html) ->
  -- | Attributes of @\<table\>@ element
  Attribute ->
  -- | Attributes for @\<tr\>@ elements in the @\<thead\>@
  Fascia p Attribute ->
  Cornice Headed p a c ->
  -- | Collection of data
  f a ->
  Html
encodeCappedTable theadAttrs tbodyAttrs trAttrs wrapContent tableAttrs fascia cornice xs = do
  let colonnade = E.discard cornice
      annCornice = E.annotate cornice
  H.table ! tableAttrs $ do
    H.thead ! theadAttrs $ do
      E.headersMonoidal
        (Just (fascia, \attrs theHtml -> H.tr ! attrs $ theHtml))
        [
          ( \msz c -> case msz of
              Just sz -> wrapContent H.th c ! HA.colspan (H.toValue (show sz))
              Nothing -> mempty
          , id
          )
        ]
        annCornice
    -- H.tr ! trAttrs $ do
    -- E.headerMonoidalGeneral colonnade (wrapContent H.th)
    encodeBody trAttrs wrapContent tbodyAttrs colonnade xs

encodeBody ::
  (Foldable f) =>
  -- | Attributes of each @\<tr\>@ element
  (a -> Attribute) ->
  -- | Wrap content and convert to 'Html'
  ((Html -> Html) -> c -> Html) ->
  -- | Attributes of @\<tbody\>@ element
  Attribute ->
  -- | How to encode data as a row
  Colonnade h a c ->
  -- | Collection of data
  f a ->
  Html
encodeBody trAttrs wrapContent tbodyAttrs colonnade xs = do
  H.tbody ! tbodyAttrs $ do
    forM_ xs $ \x -> do
      H.tr ! trAttrs x $ E.rowMonoidal colonnade (wrapContent H.td) x

{- | Encode a table. Table cells may have attributes
  applied to them.
-}
encodeCellTable ::
  (Foldable f) =>
  -- | Attributes of @\<table\>@ element
  Attribute ->
  -- | How to encode data as columns
  Colonnade Headed a Cell ->
  -- | Collection of data
  f a ->
  Html
encodeCellTable =
  encodeTable
    (E.headednessPure (mempty, mempty))
    mempty
    (const mempty)
    htmlFromCell

{- | Encode a table. Table cell element do not have
  any attributes applied to them.
-}
encodeHtmlTable ::
  (Foldable f, E.Headedness h) =>
  -- | Attributes of @\<table\>@ element
  Attribute ->
  -- | How to encode data as columns
  Colonnade h a Html ->
  -- | Collection of data
  f a ->
  Html
encodeHtmlTable =
  encodeTable
    (E.headednessPure (mempty, mempty))
    mempty
    (const mempty)
    ($)

{- | Convert a 'Cell' to 'Html' by wrapping the content with a tag
and applying the 'Cell' attributes to that tag.
-}
htmlFromCell :: (Html -> Html) -> Cell -> Html
htmlFromCell f (Cell attr content) = f ! attr $ content

data St = St
  { _stContext :: [String]
  , _stTagStatus :: TagStatus
  , stResult :: String -> String
  -- ^ difference list
  }

data TagStatus
  = TagStatusSomeTag
  | TagStatusOpening (String -> String)
  | TagStatusOpeningAttrs
  | TagStatusNormal
  | TagStatusClosing (String -> String)
  | TagStatusAfterTag

removeWhitespaceAfterTag :: String -> String -> String
removeWhitespaceAfterTag chosenTag =
  either id (\st -> stResult st "") . foldlM (flip f) (St [] TagStatusNormal id)
 where
  f :: Char -> St -> Either String St
  f c (St ctx status res) = case status of
    TagStatusNormal
      | c == '<' -> Right (St ctx TagStatusSomeTag likelyRes)
      | isSpace c ->
          if Just chosenTag == listToMaybe ctx
            then Right (St ctx TagStatusNormal res) -- drops the whitespace
            else Right (St ctx TagStatusNormal likelyRes)
      | otherwise -> Right (St ctx TagStatusNormal likelyRes)
    TagStatusSomeTag
      | c == '/' -> Right (St ctx (TagStatusClosing id) likelyRes)
      | c == '>' -> Left "unexpected >"
      | c == '<' -> Left "unexpected <"
      | otherwise -> Right (St ctx (TagStatusOpening (c :)) likelyRes)
    TagStatusOpening tag
      | c == '>' -> Right (St (tag "" : ctx) TagStatusAfterTag likelyRes)
      | isSpace c -> Right (St (tag "" : ctx) TagStatusOpeningAttrs likelyRes)
      | otherwise -> Right (St ctx (TagStatusOpening (tag . (c :))) likelyRes)
    TagStatusOpeningAttrs
      | c == '>' -> Right (St ctx TagStatusAfterTag likelyRes)
      | otherwise -> Right (St ctx TagStatusOpeningAttrs likelyRes)
    TagStatusClosing tag
      | c == '>' -> do
          otherTags <- case ctx of
            [] -> Left "closing tag without any opening tag"
            closestTag : otherTags ->
              if closestTag == tag ""
                then Right otherTags
                else Left $ "closing tag <" ++ tag "" ++ "> did not match opening tag <" ++ closestTag ++ ">"
          Right (St otherTags TagStatusAfterTag likelyRes)
      | otherwise -> Right (St ctx (TagStatusClosing (tag . (c :))) likelyRes)
    TagStatusAfterTag
      | c == '<' -> Right (St ctx TagStatusSomeTag likelyRes)
      | isSpace c ->
          if Just chosenTag == listToMaybe ctx
            then Right (St ctx TagStatusAfterTag res) -- drops the whitespace
            else Right (St ctx TagStatusNormal likelyRes)
      | otherwise -> Right (St ctx TagStatusNormal likelyRes)
   where
    likelyRes :: String -> String
    likelyRes = res . (c :)

{- | Pretty print an HTML table, stripping whitespace from inside @\<td\>@,
  @\<th\>@, and common inline tags. The implementation is inefficient and is
  incorrect in many corner cases. It is only provided to reduce the line
  count of the HTML printed by GHCi examples in this module\'s documentation.
  Use of this function is discouraged.
-}
printCompactHtml :: Html -> IO ()
printCompactHtml =
  putStrLn
    . List.dropWhileEnd (== '\n')
    . removeWhitespaceAfterTag "td"
    . removeWhitespaceAfterTag "th"
    . removeWhitespaceAfterTag "strong"
    . removeWhitespaceAfterTag "span"
    . removeWhitespaceAfterTag "em"
    . Pretty.renderHtml

{- | Similar to 'printCompactHtml'. Additionally strips all whitespace inside
  @\<tr\>@ elements and @\<thead\>@ elements.
-}
printVeryCompactHtml :: Html -> IO ()
printVeryCompactHtml =
  putStrLn
    . List.dropWhileEnd (== '\n')
    . removeWhitespaceAfterTag "td"
    . removeWhitespaceAfterTag "th"
    . removeWhitespaceAfterTag "strong"
    . removeWhitespaceAfterTag "span"
    . removeWhitespaceAfterTag "em"
    . removeWhitespaceAfterTag "tr"
    . Pretty.renderHtml

{- $discussion

In this module, some of the functions for applying a 'Colonnade' to
some values to build a table have roughly this type signature:

> Foldable a => Colonnade Headedness Cell a -> f a -> Html

The 'Colonnade' content type is 'Cell', but the content
type of the result is 'Html'. It may not be immidiately clear why
this is useful done. Another strategy, which this library also
uses, is to write
these functions to take a 'Colonnade' whose content is 'Html':

> Foldable a => Colonnade Headedness Html a -> f a -> Html

When the 'Colonnade' content type is 'Html', then the header
content is rendered as the child of a @\<th\>@ and the row
content the child of a @\<td\>@. However, it is not possible
to add attributes to these parent elements. To accomodate this
situation, it is necessary to introduce 'Cell', which includes
the possibility of attributes on the parent node.
-}
