--[[
The MIT License (MIT)

Copyright (c) 2016 Daniel Rasmussen

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

local ffi = require("ffi")
local utf8 = require("utf8")
local artalFunction = {}
artalFunction.version = "1.1"

--[[~~~~~~~~~~~~~~~~~~ Version 1.1 change log ~~~~~~~~~~~~~~~~~~
-- Fixed error in the image loading routine that caused it to incorrectly 
   determine the size of image. Thus loading garbage data.
--]]

local function hexToNumber(first,second,third,forth) -- first is the direct hex -- Lack 8 length support
	local result = first
	
	if forth ~= nil then
		result = result + second * ( 0xff +1)
		result = result + third * ( 0xffff +1)
		result = result + forth * ( 0xffffff +1)
	elseif third ~= nil then
		result = result + second * ( 0xff +1)
		result = result + third * ( 0xffff +1)
	elseif second ~= nil then
		result = result + second * ( 0xff +1)
	end

	return result
end


local function directFileReader(C_fileData)
	local self = {}
	self.count = 0

	function self:inkString(name , stringLength , stepLength)
		-- Step length needs to grab 2 bytes in some cases.
		if stepLength == nil then stepLength = 1 end
		assert(self[name] == nil , "Artal: Name already taken.")


		local resultString = ""
		for i = 1 , stringLength do

			local first = C_fileData[self.count]
			local second
			local third
			local forth

			if stepLength == 2 then
				second = C_fileData[self.count+1]
			elseif stepLength == 4 then
				second = C_fileData[self.count+1]
				third = C_fileData[self.count+2]
				forth = C_fileData[self.count+3]
			end


			local resultStringAdd = hexToNumber(first,second,third,forth)
			self.count = self.count + stepLength

			--print(resultStringAdd)
			if resultStringAdd > 31 and resultStringAdd < 127 then 
				--resultString = resultString.." \""..tostring(resultStringAdd).." "
				resultString = resultString..string.char(resultStringAdd)
			end
		end

		if name ~= nil then
			self[name] = resultString
		end
		--print(name..": ",self[name])
		return resultString
	end

	function self:inkUnicodeString(name , stringLength)
		-- Step length needs to grab 2 bytes in some cases.
		assert(self[name] == nil , "Artal: Name already taken.")

		self.count = self.count + 4
		stringLength = (stringLength - 4) / 2

		local result = {}
		for i = 1 , stringLength do

			local first = C_fileData[self.count]
			local second = C_fileData[self.count+1]


			local byte = hexToNumber(second, first)
			self.count = self.count + 2

			if byte ~= 0 then
				table.insert(result, byte)
			end
		end

		result = utf8.char(unpack(result))
		if name ~= nil then
			self[name] = result
		end
		return result
	end

	function self:ink(name , stepLength, div) -- Lack 8 length support
		
		assert(stepLength == 1 or stepLength == 2 or stepLength == 4 ,"Artal: ink must be a power of 2. No higher than 4.")

		local first = C_fileData[self.count]
		local second
		local third
		local forth

		if stepLength == 2 then
			second = C_fileData[self.count+1]
			first , second = second , first
		elseif stepLength == 4 then
			second = C_fileData[self.count+1]
			third = C_fileData[self.count+2]
			forth = C_fileData[self.count+3]
			first , second , third , forth = forth, third , second , first
		end


		if div ~= "don't count" then self.count = self.count + stepLength end
		local resultString = hexToNumber(first,second,third,forth)


		if div == "int" and resultString >= 2^(stepLength*8-1) then
			resultString = resultString - 2^(stepLength*8)
		end


		if name == nil then
			return resultString
		end

		if name == tonumber(name) then
			name = tonumber(name)
		end
		
		assert(self[name] == nil , "Artal: Name already taken.")
		self[name] = resultString
		--print(name..": ",self[name])
	end

	--[[
	function self:ink__SLOWANDCLEAN(name , stepLength, div) -- Lack 8 length support, Should create a C-type int64_t
		
		assert(stepLength == 1 or stepLength == 2 or stepLength == 4 ,"Artal: ink must be a power of 2. No higher than 4.")

		local result = 0
		for i = stepLength, 1, -1 do
			result = result + C_fileData[self.count-1+i] * 2^((stepLength-i)*8)
		end
		
		

		if div ~= "don't count" then self.count = self.count + stepLength end

		if div == "int" and result >= 128 then
			assert(stepLength == 1, "Artal: Function :ink does not handle \"int\" longer than 1 byte.")
			result = result - 256
		end

		if name == nil then
			return result
		end

		if name == tonumber(name) then
			name = tonumber(name)
		end
		
		assert(self[name] == nil , "Artal: Name already taken.")
		self[name] = result
		--print(name..": ",self[name])
	end
	--]]

	return self
end

local function artalNewLayerImageData(layerLoadData,askIsImageLayer)
	local commonAssertMsg = ", make sure to only pass in data formed by the newPSD() function."
	assert(layerLoadData.fileData ~= nil, "Artal: newLayer layerLoadData.fileData is nil"..commonAssertMsg)
	assert(layerLoadData.fileData:type() == "FileData", "Artal: newLayer layerLoadData.fileData is not FileData"..commonAssertMsg)
	assert(layerLoadData ~= nil, "Artal: newLayer layerLoadData is nil"..commonAssertMsg)

	local image = layerLoadData

	local C_fileData = ffi.cast("uint8_t *", image.fileData:getPointer())
	local artal = directFileReader(C_fileData)

	assert(artal:inkString(nil,4) == "8BPS", "Artal: newLayer layerLoadData.fileData is not a .psd file"..commonAssertMsg)
	artal.count = artal.count - 4

	local clampX = 0
	if image.left < 0 then
		clampX = image.left
		--print("Clamped at X:",clampX)
	end
	local clampY = 0
	if image.top < 0 then
		clampY = image.top
		--print("Clamped at Y:",clampY)
	end
	local clampW
	if image.right > image.globalWidth then
		clampW = image.globalWidth - image.left
		--print("Clamped at W:",clampW)
	else
		clampW = image.right - image.left
	end
	local clampH
	if image.bottom > image.globalHeight then
		clampH = image.globalHeight - image.top
		--print("Clamped at H:",clampH)
	else
		clampH = image.bottom - image.top
	end

	
	local dataSize = clampW*clampH*4
	-- Shouldn't ever be negative. But the docs doesn't spesify.
	if dataSize < 0 then dataSize = 0 end

	if askIsImageLayer then
		if dataSize == 0 then
			return false
		else
			return true -- early out
		end
	end

	local C_data
	local imageData
	if dataSize ~= 0 then
		imageData = love.image.newImageData(clampW + clampX, clampH + clampY)
		C_data = ffi.cast("char *", imageData:getPointer())
	end
	local lineInfo = {}
	--print(clampW,clampH)
	--print(image.channelPointer[1])
	--print(image.channelPointer[2])
	--print(image.channelPointer[3])
	--print(image.channelPointer[4])
	--print(image.left, image.right)
	for CC = 1 , #image.channelID do
		artal.count = image.channelPointer[CC]
		local channelCompression = artal:ink(nil,2)
		local alphaOpacity = 1
		local cPixelPos
		if image.channelID[CC] == -1 then
			cPixelPos = 3
			alphaOpacity = image.opacity / 255
		elseif image.channelID[CC] == 0 then
			cPixelPos = 0
		elseif image.channelID[CC] == 1 then
			cPixelPos = 1
		elseif image.channelID[CC] == 2 then
			cPixelPos = 2
		else
			assert(false,"Artal: Unsupported channel id/mode.")
		end

		
		if channelCompression == 1 then

			for LINE = 1 , image.totalHeight do
				-- Bytes per line
				lineInfo[LINE] = artal:ink(nil,2)
				--print(CC,lineInfo[LINE] )
			end
			
			local yPixelPos = clampY
			for LINE = 1, image.totalHeight do

				--print(LINE)

				local countEnd = artal.count + lineInfo[LINE]
				--print(artal.count , countEnd,lineInfo[LINE])
				--print("INTO")

				--print("line",LINE,yPixelPos)
				if yPixelPos >= 0 then
					if yPixelPos < clampH + clampY then
						local xPixelPos = clampX
						while artal.count < countEnd do

							local headByte = artal:ink(nil,1,"int")
							--print("head",headByte)
							if headByte >= 0 then
								for i = 1, 1 + headByte do
									-- Literal pixels
									local pixelValue = artal:ink(nil,1) * alphaOpacity
									if xPixelPos >= 0 and xPixelPos < clampX+clampW then
										-- Here be valid pixels
										local pos = cPixelPos + (xPixelPos*4) + (yPixelPos*(clampW+clampX)*4)
										--print(CC,xPixelPos,yPixelPos,pos,pixelValue,(clampW+clampX))
										C_data[pos] = pixelValue
									end
									xPixelPos = xPixelPos + 1
								end
							elseif headByte > -128 then
								local pixelValue = artal:ink(nil,1) * alphaOpacity
								for i = 1 , 1 - headByte do
									-- Repeat pixels
									if xPixelPos >= 0 and xPixelPos < clampX+clampW then
										-- Here be valid pixels
										local pos = cPixelPos + (xPixelPos*4) + (yPixelPos*(clampW+clampX)*4)
										--print(CC,xPixelPos,yPixelPos,pos,pixelValue,(clampW+clampX))
										C_data[pos] = pixelValue
									end
									xPixelPos = xPixelPos + 1
								end
							else
								artal:ink(nil,1)
							end
						end
						--assert(artal.count == countEnd,"Artal: Error reading layerdata.")
					else
						--print(yPixelPos)
						break -- All pixels you want are now filled.
					end
				else
					artal.count = countEnd
				end
				yPixelPos = yPixelPos + 1
			end
		elseif channelCompression == 0 then

			--if(CC == 2) then
			--artal.count = (yPixelPos*clampW*4)
			for y = -clampY, clampH - 1 do
				for x = -clampX, clampW - 1 do
					--print(x,y)
					local pixelPos = (y*(clampW)+x)*4+cPixelPos
					local dataPos = y*(clampW)+x
					C_data[pixelPos] = C_fileData[artal.count + dataPos] * alphaOpacity
					--print(x, y, pixelPos, dataPos, C_fileData[artal.count + dataPos])
				end
			end
			--end
		else
			assert(false, "Artal: Unsupported compression mode:"..channelCompression)
		end
	end
	if #image.channelID == 3 then -- Set opacity.
		for i = 0, dataSize,4 do
			C_data[i+3] = image.opacity
		end
	end

	if dataSize == 0 then
		return nil
	else
		return imageData
	end
end

local function defaultLoadImageFunction(artalLayer,layerLoadData,folderStack,layerNumber)

	local layer = {}
	layer.name = artalLayer.betterName
	layer.blend = artalLayer.betterBlend
	if artalLayer.betterCliping == 0 then
		layer.clip = false
	else
		layer.clip = true
	end

	local imageData = artalNewLayerImageData(layerLoadData)
	if imageData then
		layer.image = love.graphics.newImage(imageData)
		if layer.clip then
			layer.image:setWrap("clampzero")
		end
		layer.type = "image"
		layer.ox = 0
		layer.oy = 0
		if artalLayer.left > 0 then
			layer.ox = -artalLayer.left
		end
		if artalLayer.top > 0 then
			layer.oy = -artalLayer.top
		end
	else
		layer.type = "empty"
	end
	return layer
end

local function defaultLoadImageInfoFunction(artalLayer,layerLoadData,folderStack,layerNumber)

	local layer = {}
	layer.name = artalLayer.betterName
	layer.blend = artalLayer.betterBlend
	if artalLayer.betterCliping == 0 then
		layer.clip = false
	else
		layer.clip = true
	end

	local thereExistImageData = artalNewLayerImageData(layerLoadData,true)
	if thereExistImageData then
		layer.type = "image"
		layer.ox = 0
		layer.oy = 0
		if artalLayer.left > 0 then
			layer.ox = -artalLayer.left
		end
		if artalLayer.top > 0 then
			layer.oy = -artalLayer.top
		end
	else
		layer.type = "empty"
	end
	return layer
end

local function defaultLoadFolderFunction(artalLayer,layerLoadData)
	local layer = {}


	layer.name = artalLayer.betterName
	layer.blend = artalLayer.betterBlend
	if artalLayer.betterCliping == 0 then
		layer.clip = false
	else
		layer.clip = true
	end

	if artalLayer.folder == 3 then
		layer.type = "open"
	elseif artalLayer.folder == 1 or artalLayer.folder == 2 then
		layer.type = "close"
	end

	return layer
end

function artalFunction.newPSD(fileNameOrData, structureFlagOrNumber)
	local GC_C_fileData

	if type(fileNameOrData) == "string" then
		assert(love.filesystem.exists(fileNameOrData), "Artal: PSD file do not exist.")
		GC_C_fileData = love.filesystem.newFileData(fileNameOrData)
	elseif type(fileNameOrData) == "userdata" and fileNameOrData:type() == "FileData" then
		GC_C_fileData = fileNameOrData
	else
		assert(false,"Artal: fileName is not a string or FileData.")
	end
	local C_fileData = ffi.cast("uint8_t *", GC_C_fileData:getPointer())


	local artal = directFileReader(C_fileData)

	artal.startPoint = {}
	artal.warning = {}

	-- Header
	assert(artal:inkString(nil,4) == "8BPS" , "Artal: File must be a .psd.")
	assert(artal:ink(nil,2) == 1 , "Artal: File must be a .psd") 
	artal.count = artal.count + 6 --Reserved space
	artal:ink("channelCount",2)
	artal:ink("height",4)
	artal:ink("width",4)
	artal:ink("depth",2)
	assert(artal.depth == 8, "Artal: Image must be a 8 bit image")
	artal:ink("colorMode",2)
	assert(artal.colorMode == 3, "Artal: RGB is the only supported color mode")

	--Color Mode
	artal:ink("colorModeLength",4)
	assert(artal.colorModeLength == 0 ,"Artal: Color Mode Length is not 0 as expected.")


	--Image Resources Section
	artal:ink("imageResourcesLength",4)
	artal.startPoint.layerMask = artal.count + artal.imageResourcesLength
	assert(artal:inkString(nil,4) == "8BIM" , "Artal: imageResources Signature is not correct.")
	artal:ink("imageResourcesID",2)
	-- Stub



	--Layer and Mask
	artal.count = artal.startPoint.layerMask
	--Layer and mask information section
	artal:ink("layerLength",4)
	artal.startPoint.imageData = artal.count + artal.layerLength
	--Layer info
	artal:ink("layerTotalLength",4)
	artal:ink("layerTotalCount",2,"int")-- Don't really know why this can be a negative number.

	artal.layer = {}
	--print(artal.layerTotalCount)
	local opacityBakingTable = {}
	for LC = 1 , math.abs(artal.layerTotalCount) do
		artal.layer[LC] = directFileReader(C_fileData)
		artal.layer[LC].count = artal.count
		--print("artal.layer["..LC.."]")

		--Layer records
		artal.layer[LC]:ink("top",4,"int")
		artal.layer[LC]:ink("left",4,"int")
		artal.layer[LC]:ink("bottom",4,"int")
		artal.layer[LC]:ink("right",4,"int")

		artal.layer[LC]:ink("channelCount",2)
		assert(artal.layer[LC].channelCount == 4 or artal.layer[LC].channelCount == 3,
			"Artal: Only supports 3 or 4 channels." )

		artal.layer[LC].channel = {}


		for CC = 1 , artal.layer[LC].channelCount do

			artal.layer[LC].channel[CC] = directFileReader(C_fileData)
			artal.layer[LC].channel[CC].count = artal.layer[LC].count


			artal.layer[LC].channel[CC]:ink("id",2,"int")
			assert(
				artal.layer[LC].channel[CC].id == 0 or
				artal.layer[LC].channel[CC].id == 1 or
				artal.layer[LC].channel[CC].id == 2 or
				artal.layer[LC].channel[CC].id == -1,
				"Artal: Unsupported channel ID: "..artal.layer[LC].channel[CC].id)
			artal.layer[LC].channel[CC]:ink("length",4)

			artal.layer[LC].count = artal.layer[LC].channel[CC].count
		end


		assert(artal.layer[LC]:inkString(nil,4) == "8BIM" , "Artal: Layer Records Signature is not correct.")
		artal.layer[LC]:inkString("blend",4)
		artal.layer[LC].blendShortName = string.gsub(artal.layer[LC].blend," ","")
		artal.layer[LC]:ink("opacity",1)
		artal.layer[LC].bakedOpacity = artal.layer[LC].opacity -- This is modified later if folders has opacity.
		artal.layer[LC]:ink("clipping",1)
		artal.layer[LC]:ink("flags",1)	--Prehaps make a inkBits that expose the 8 bits in a hex
		artal.layer[LC].count = artal.layer[LC].count + 1 -- Pad
		artal.layer[LC]:ink("additionalLength",4)

		--Layer mask / adjustment layer data
		artal.layer[LC]:ink("maskAdjustment",4)
		assert(artal.layer[LC].maskAdjustment == 0, "Artal: maskAdjustment is not 0 as expected.")
		--Layer blending ranges data
		artal.layer[LC]:ink("blendingRangeLength",4) -- Jumping over this
		artal.layer[LC].count = artal.layer[LC].count + artal.layer[LC].blendingRangeLength
		--Layer Name
		artal.layer[LC]:ink("nameLength",1)
		artal.layer[LC]:inkString("name",artal.layer[LC].nameLength)
		-- This is modified later if the folder is "close" so folders open/close have the same name / blend / clip.
		artal.layer[LC].betterName = artal.layer[LC].name
		artal.layer[LC].betterBlend = artal.layer[LC].blendShortName
		artal.layer[LC].betterCliping = artal.layer[LC].clipping

		--Pascal String padding
		if ((artal.layer[LC].nameLength+1)/4) ~= math.floor((artal.layer[LC].nameLength+1)/4) then
			artal.layer[LC].count = artal.layer[LC].count + math.ceil((artal.layer[LC].nameLength+1)/4)*4 - ((artal.layer[LC].nameLength+1)/4)*4
		end

		local syncFolderNameFlag = false
		-- Additional Layer Information
		while artal.layer[LC]:inkString(nil , 4) == "8BIM" do
			local key = artal.layer[LC]:inkString(nil,4)
			local length = artal.layer[LC]:ink(nil,4)
			--print("key: "..key.." , Length: "..length)


			if key == "luni" then
				artal.layer[LC].betterName = artal.layer[LC]:inkUnicodeString("luniName",length)
			elseif key == "lnsr" then
				artal.layer[LC]:inkString("layerID",4)
			elseif key == "lyid" then
				artal.layer[LC]:ink("lyid",4) -- Seems errorious
			elseif key == "clbl" then
				artal.layer[LC]:ink("blendClippedElements",1) -- true == 1 / false == 0
				artal.layer[LC].count = artal.layer[LC].count + 3
			elseif key == "infx" then
				artal.layer[LC]:ink("blendInteriorElements",1) -- true == 1 / false == 0
				artal.layer[LC].count = artal.layer[LC].count + 3
			elseif key == "knko" then
				artal.layer[LC]:ink("knockoutSetting",1) -- true == 1 / false == 0
				artal.layer[LC].count = artal.layer[LC].count + 3
			elseif key == "lspf" then
				artal.layer[LC]:ink("protectionFlags",4)
			elseif key == "lclr" then
				artal.layer[LC]:ink("sheetColorSetting",4) 
				artal.layer[LC].count = artal.layer[LC].count + 4 -- Pad
			elseif key == "shmd" then
				artal.layer[LC].count = artal.layer[LC].count + length -- Undocumented
			elseif key == "fxrp" then
				artal.layer[LC]:ink("referencePoint1",4)
				artal.layer[LC]:ink("referencePoint1big",4)
				artal.layer[LC]:ink("referencePoint2",4)
				artal.layer[LC]:ink("referencePoint2big",4)
			elseif key == "lsct" then
				artal.layer[LC]:ink("folder",4)
				if artal.layer[LC].folder == 3 then
					table.insert(opacityBakingTable,LC)
				elseif artal.layer[LC].folder == 1 or artal.layer[LC].folder == 2 then
					-- There is no guarantee that "luniName" has been set at this point
					-- so I defer the renaming of folders until after all flags have been read.
					syncFolderNameFlag = true
				end
				if length >= 12 then
					assert(artal.layer[LC]:inkString(nil,4) == "8BIM" , "Artal: lsct signature is not correct.")
					artal.layer[LC]:inkString("sectionDividerBlend",4)
				end
				if length >= 16 then
					artal.layer[LC]:ink("sectionDividerType",4)
				end
			elseif key == "lyvr" then
				artal.layer[LC]:ink("layerVersion",4)
			elseif key == "lfx2" then
				assert(artal.layer[LC]:ink(nil,4) == 0 , "Artal: objectivVersion is not 0 as expected.")
				artal.layer[LC]:ink("descriptorVersion",4)
				--Stub
				artal.layer[LC].count = artal.layer[LC].count - 8 + length
			elseif key == "lrFX" then
				--Stub
				artal.layer[LC].count = artal.layer[LC].count + length

			else
				artal.warning[key] = "Key: \""..key.."\" is not yet handled."
				artal.layer[LC].count = artal.layer[LC].count + length
				--assert(false,"Artal: Key: \""..key.."\" is not yet handled.")
			end

		end

		if syncFolderNameFlag == true then
			local startCounter = opacityBakingTable[#opacityBakingTable]

			artal.layer[startCounter].betterName = artal.layer[LC].betterName
			artal.layer[startCounter].betterBlend = artal.layer[LC].betterBlend
			artal.layer[startCounter].betterCliping = artal.layer[LC].betterClipping
			for LCback = startCounter, LC - 1 do
				artal.layer[LCback].bakedOpacity =
					artal.layer[LCback].bakedOpacity * (artal.layer[LC].opacity/255)
				--print(artal.layer[LCback].name,artal.layer[LCback].bakedOpacity)
			end
			table.remove(opacityBakingTable)
		end



		-- Back up the last false while loop 
		artal.layer[LC].count = artal.layer[LC].count - 4 
		

		artal.count = artal.layer[LC].count
	end

	if math.abs(artal.layerTotalCount) > 0 then
		local startPointer = artal.count
		for LC = 1 , math.abs(artal.layerTotalCount) do
			for CC = 1 , artal.layer[LC].channelCount do
				artal.layer[LC].channel[CC].pointer = startPointer
				startPointer = startPointer + artal.layer[LC].channel[CC].length
			end
		end
	end

	if structureFlagOrNumber == "composed" then
		artal.count = artal.startPoint.imageData
		artal.channel = {}
		local imageData = love.image.newImageData(artal.width,artal.height)
		local C_data = ffi.cast("uint8_t *", imageData:getPointer())

		local cPixelPos
		
		assert(artal.channelCount == 3 or artal.channelCount == 4, "Artal: Composed image only supports 3 or 4 channels of imagedata.")

		artal:ink("compression",2)

		

		if artal.compression == 1 then

			for CC = 1, artal.channelCount do
				artal.channel[CC] = directFileReader(C_fileData)
				artal.channel[CC].count = artal.count

				artal.channel[CC].lineInfo = {}
				for LINE = 1 , artal.height do
					-- Bytes per line
					artal.channel[CC].lineInfo[LINE] = artal.channel[CC]:ink(nil,2)
					--print(artal.channel[CC].lineInfo[LINE],LINE)
				end
				
				artal.count = artal.channel[CC].count
			end
			for CC = 1, artal.channelCount do
				artal.channel[CC].count = artal.count
				local cPixelPos = CC - 1
				for LINE = 1, artal.height do
					local countEnd = artal.channel[CC].count + artal.channel[CC].lineInfo[LINE]

					local yPixelPos = LINE - 1
					local xPixelPos = 0

					while artal.channel[CC].count < countEnd do -- These two should end up equal

						local headByte = artal.channel[CC]:ink(nil,1,"int")
						--print("head",headByte)
						if headByte >= 0 then
							for i = 1, 1 + headByte do
								-- Literal pixels
								local pixelValue = artal.channel[CC]:ink(nil,1)
								-- Here be valid pixels
								C_data[cPixelPos + (xPixelPos*4) + (yPixelPos*artal.width*4)] = pixelValue
								--print(CC,xPixelPos,yPixelPos,cPixelPos)
								xPixelPos = xPixelPos + 1
							end
						elseif headByte > -128 then
							local pixelValue = artal.channel[CC]:ink(nil,1)
							for i = 1 , 1 - headByte do
								-- Repeat pixels
								-- Here be valid pixels
								C_data[cPixelPos + (xPixelPos*4) + (yPixelPos*artal.width*4)] = pixelValue
								--print(CC,xPixelPos,yPixelPos,cPixelPos)
								xPixelPos = xPixelPos + 1
							end
						else
							artal.channel[CC]:ink(nil,1)
						end
					end
					--assert(artal.channel[CC].count == countEnd,"Artal: Error reading layerdata.")
				end

				artal.count = artal.channel[CC].count
			end

		elseif artal.compression == 0 then
			for CC = 1, artal.channelCount do
				cPixelPos = CC - 1
				for y = 0, artal.height - 1 do
					for x = 0, artal.width - 1 do
						--print(x,y)
						local pixelPos = (y*artal.width+x)*4+cPixelPos
						local dataPos = y*artal.width+x+(cPixelPos*artal.height*artal.width)
						C_data[pixelPos] = C_fileData[artal.count + dataPos]

						--print(pixelPos, dataPos)
					end
				end
			end
		else
			assert(false,"Artal: Unsupported compression mode for composed image.")
		end

		if artal.channelCount == 3 then -- Set opacity to full
			for i = 0, artal.width*artal.height*4,4 do
				C_data[i+3] = 255
			end
		end
		--artal.image = love.graphics.newImage(imageData)
		return imageData -- Early out for composed mode.
	end

	local function imageDataForLayer(globalData,layerData,fileData)
		local layerLoadData = {}
		layerLoadData.left = layerData.left
		layerLoadData.right = layerData.right
		layerLoadData.top = layerData.top
		layerLoadData.bottom = layerData.bottom
		layerLoadData.channelPointer = {}
		layerLoadData.channelID = {}
		layerLoadData.opacity = layerData.bakedOpacity
		for CC = 1, layerData.channelCount do
			layerLoadData.channelPointer[CC] = layerData.channel[CC].pointer
			layerLoadData.channelID[CC] = layerData.channel[CC].id
		end
		layerLoadData.globalWidth = globalData.width
		layerLoadData.globalHeight = globalData.height

		layerLoadData.totalWidth = layerLoadData.right - layerLoadData.left
		layerLoadData.totalHeight = layerLoadData.bottom - layerLoadData.top
		layerLoadData.fileData = fileData

		return layerLoadData
	end

	if structureFlagOrNumber == nil or structureFlagOrNumber == "info" then
		local imageTable =
		{
			width = artal.width,
			height = artal.height
		}

		for LC = 1 , math.abs(artal.layerTotalCount) do
			local layerLoadData = imageDataForLayer(artal,artal.layer[LC],GC_C_fileData)
			
			if artal.layer[LC].folder == 1 or artal.layer[LC].folder == 2 or artal.layer[LC].folder == 3 then
				imageTable[LC] = defaultLoadFolderFunction(artal.layer[LC],layerLoadData)
			else
				if structureFlagOrNumber == "info" then
					imageTable[LC] = defaultLoadImageInfoFunction(artal.layer[LC],layerLoadData)
				else
					imageTable[LC] = defaultLoadImageFunction(artal.layer[LC],layerLoadData)
				end
			end
		end
		
		return imageTable
	elseif type(structureFlagOrNumber) == "number" then
		local layerLoadData = imageDataForLayer(artal,artal.layer[structureFlagOrNumber],GC_C_fileData)
		local imageData = artalNewLayerImageData(layerLoadData)

		return imageData
	end
end

return artalFunction

--[[
Adobe documentation on the PSD file format.
http://www.adobe.com/devnet-apps/photoshop/fileformatashtml/
--]]
-- Assemble our bodies.
