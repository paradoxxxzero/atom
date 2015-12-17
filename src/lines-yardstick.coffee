TokenIterator = require './token-iterator'
{Point} = require 'text-buffer'
{isPairedCharacter} = require './text-utils'

module.exports =
class LinesYardstick
  constructor: (@model, @lineNodesProvider, grammarRegistry) ->
    @tokenIterator = new TokenIterator({grammarRegistry})
    @rangeForMeasurement = document.createRange()
    @invalidateCache()

  invalidateCache: ->
    @leftPixelPositionCache = {}

  measuredRowForPixelPosition: (pixelPosition) ->
    targetTop = pixelPosition.top
    row = Math.floor(targetTop / @model.getLineHeightInPixels())
    row if 0 <= row <= @model.getLastScreenRow()

  screenPositionForPixelPosition: (pixelPosition) ->
    targetTop = pixelPosition.top
    targetLeft = pixelPosition.left
    row = Math.floor(targetTop / @model.getLineHeightInPixels())
    targetLeft = 0 if row < 0
    targetLeft = Infinity if row > @model.getLastScreenRow()
    row = Math.min(row, @model.getLastScreenRow())
    row = Math.max(0, row)

    lineNode = @lineNodesProvider.lineNodeForScreenRow(row)
    return Point(row, 0) unless lineNode

    textNodes = @lineNodesProvider.textNodesForScreenRow(row)
    lineOffset = lineNode.getBoundingClientRect().left
    targetLeft += lineOffset

    textNodeStartColumn = 0
    for textNode in textNodes
      {length: textNodeLength, textContent: textNodeContent} = textNode
      textNodeRight = @clientRectForRange(textNode, 0, textNodeLength).right

      if textNodeRight > targetLeft
        characterIndex = 0
        while characterIndex < textNodeLength
          if isPairedCharacter(textNodeContent, characterIndex)
            nextCharacterIndex = characterIndex + 2
          else
            nextCharacterIndex = characterIndex + 1

          rangeRect = @clientRectForRange(textNode, characterIndex, nextCharacterIndex)

          if rangeRect.right > targetLeft
            if targetLeft <= ((rangeRect.left + rangeRect.right) / 2)
              return Point(row, textNodeStartColumn + characterIndex)
            else
              return Point(row, textNodeStartColumn + nextCharacterIndex)
          else
            characterIndex = nextCharacterIndex

      textNodeStartColumn += textNodeLength

    Point(row, textNodeStartColumn)

  pixelPositionForScreenPosition: (screenPosition, clip=true) ->
    screenPosition = Point.fromObject(screenPosition)
    screenPosition = @model.clipScreenPosition(screenPosition) if clip

    targetRow = screenPosition.row
    targetColumn = screenPosition.column

    top = targetRow * @model.getLineHeightInPixels()
    left = @leftPixelPositionForScreenPosition(targetRow, targetColumn)

    {top, left}

  leftPixelPositionForScreenPosition: (row, column) ->
    lineNode = @lineNodesProvider.lineNodeForScreenRow(row)
    lineId = @lineNodesProvider.lineIdForScreenRow(row)

    return 0 unless lineNode?

    if cachedPosition = @leftPixelPositionCache[lineId]?[column]
      return cachedPosition

    textNodes = @lineNodesProvider.textNodesForScreenRow(row)
    textNodeStartColumn = 0

    for textNode in textNodes
      textNodeEndColumn = textNodeStartColumn + textNode.textContent.length
      if textNodeEndColumn > column
        indexInTextNode = column - textNodeStartColumn
        break
      else
        textNodeStartColumn = textNodeEndColumn

    if textNode?
      indexInTextNode ?= textNode.textContent.length
      lineOffset = lineNode.getBoundingClientRect().left
      if indexInTextNode is 0
        leftPixelPosition = @clientRectForRange(textNode, 0, 1).left
      else
        leftPixelPosition = @clientRectForRange(textNode, 0, indexInTextNode).right
      leftPixelPosition -= lineOffset

      @leftPixelPositionCache[lineId] ?= {}
      @leftPixelPositionCache[lineId][column] = leftPixelPosition
      leftPixelPosition
    else
      0

  clientRectForRange: (textNode, startIndex, endIndex) ->
    @rangeForMeasurement.setStart(textNode, startIndex)
    @rangeForMeasurement.setEnd(textNode, endIndex)
    @rangeForMeasurement.getBoundingClientRect()
