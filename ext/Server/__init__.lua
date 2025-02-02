class 'BetterIngameAdmin'

function BetterIngameAdmin:__init()
    print("Initializing BetterIngameAdmin")
    self:RegisterVars()
    self:RegisterCommands()
    self:RegisterEvents()
end

function BetterIngameAdmin:RegisterVars()
	-- Region Vote stuff
    self.voteInProgress = false
	self.typeOfVote = ""
	self.playersVotedYes = {}
	self.playersVotedNo = {}
	self.playersVotedYesCount = 0
	self.playersVotedNoCount = 0
	self.playerToVote = nil
	self.playerToVoteAccountGuid = nil
	self.playerStartedVoteCounter = {}
		
	self.cumulatedTime = 0
	
	self.cooldownIsRunning = false
	self.cumulatedCooldownTime = 0
	-- Endregion
	
	-- Region AdminList
	self.adminList = {}
	-- Endregion
	
	-- Region Assist
	self.queueAssistList1 = {}
	self.queueAssistList2 = {}
	self.queueAssistList3 = {}
	self.queueAssistList4 = {}
	-- Endregion
	
	-- Region ServerBanner LoadingScreen
	self.bannerUrl = "fb://UI/Static/ServerBanner/BFServerBanner"
	self.serverName = nil
	self.serverDescription = nil
	-- Endregion
	
	-- Region save serverInfo for joining players
	self.serverConfig = {}
	-- Endregion
	
	-- Region ServerOwner
	self.owner = nil
	self.loggedOwner = false
	-- Endregion
	
	-- Region ModSettings
	self.loadedModSettings = false
	self.showEnemyCorpses = true
	self.voteDuration = 30
	self.cooldownBetweenVotes = 0
	self.maxVotingStartsPerPlayer = 3
	self.votingParticipationNeeded = 50
	self.enableAssistFunction = true
	-- Endregion
	
	-- Region Ping for Scoreboard
	self.cumulatedTimeForPing = 0
	-- Endregion
end

function BetterIngameAdmin:RegisterCommands()
	-- Region ServerBanner
	RCON:RegisterCommand("vars.bannerUrl", RemoteCommandFlag.None, function(command, args, loggedIn)
		if args ~= nil then
			if args[1] == "" then
				self.bannerUrl = "fb://UI/Static/ServerBanner/BFServerBanner"
				NetEvents:Broadcast('Info', {self.serverName, self.serverDescription, self.bannerUrl})
				print("SET BANNER: Default")
				return {'OK', self.bannerUrl}
			elseif args[1] ~= nil then
				self.bannerUrl = args[1]
				NetEvents:Broadcast('Info', {self.serverName, self.serverDescription, self.bannerUrl})
				print("SET BANNER: " .. args[1])
				return {'OK', args[1]}
			else
				print("GET BANNER: " .. self.bannerUrl)
				return {'OK', self.bannerUrl}
			end
		else
			print("GET BANNER: " .. self.bannerUrl)
			return {'OK', self.bannerUrl}
		end
	end)
	-- Endregion
	
	-- Region Server Owner
	RCON:RegisterCommand('vars.serverOwner', RemoteCommandFlag.RequiresLogin, function(command, args, loggedIn)
		if not SQL:Open() then
			return
		end
		
		local query = [[
		  CREATE TABLE IF NOT EXISTS server_owner (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			text_value TEXT
		  )
		]]
		if not SQL:Query(query) then
		  print('Failed to execute query: ' .. SQL:Error())
		  return
		end
		
		-- Fetch all rows from the table.
		results = SQL:Query('SELECT * FROM server_owner')

		if not results then
		  print('Failed to execute query: ' .. SQL:Error())
		  return
		end
		
		-- Print the fetched rows.
		for _, row in pairs(results) do
			self.owner = row["text_value"]
		end
		SQL:Close()
		if self.owner ~= nil then
			if self.loggedOwner == false then
				print("GET SERVER OWNER: " .. self.owner)
				self.loggedOwner = true
			end
			return {'OK', self.owner}
		else
			if self.loggedOwner == false then
				print("GET SERVER OWNER: CAUTION NO SERVER OWNER SET! PLEASE JOIN YOUR SERVER!")
			end
			return {'OK', 'OwnerNotSet'}
		end
	end)
	-- Endregion
end

function BetterIngameAdmin:RegisterEvents()
	-- Region Vote stuff
    NetEvents:Subscribe('VotekickPlayer', self, self.OnVotekickPlayer)
    NetEvents:Subscribe('VotebanPlayer', self, self.OnVotebanPlayer)
	NetEvents:Subscribe('Surrender', self, self.OnSurrender)
	NetEvents:Subscribe('CheckVoteYes', self, self.OnCheckVoteYes)
	NetEvents:Subscribe('CheckVoteNo', self, self.OnCheckVoteNo)
    Events:Subscribe('Engine:Update', self, self.OnEngineUpdate)
	-- self:EndVote()
	-- Endregion
	
	-- Region Admin gameAdmin Events Dispatch/ Subscribe
	Events:Subscribe('GameAdmin:Player', self, self.OnGameAdminPlayer)
	Events:Subscribe('GameAdmin:Clear', self, self.OnGameAdminClear)
	-- Endregion
	
	-- Region Admin actions for players
	NetEvents:Subscribe('MovePlayer', self, self.OnMovePlayer)
	NetEvents:Subscribe('KillPlayer', self, self.OnKillPlayer)
	NetEvents:Subscribe('KickPlayer', self, self.OnKickPlayer)
	NetEvents:Subscribe('TBanPlayer', self, self.OnTBanPlayer)
	NetEvents:Subscribe('BanPlayer', self, self.OnBanPlayer)
	NetEvents:Subscribe('DeleteAdminRights', self, self.OnDeleteAdminRights)
	NetEvents:Subscribe('DeleteAndSaveAdminRights', self, self.OnDeleteAndSaveAdminRights)
	NetEvents:Subscribe('UpdateAdminRights', self, self.OnUpdateAdminRights)
	NetEvents:Subscribe('UpdateAndSaveAdminRights', self, self.OnUpdateAndSaveAdminRights)
	NetEvents:Subscribe('GetAdminRightsOfPlayer', self, self.OnGetAdminRightsOfPlayer)
	-- Endregion
	
	
	-- Region Player Assist enemy team
	NetEvents:Subscribe('AssistEnemyTeam', self, self.OnAssistEnemyTeam)
	NetEvents:Subscribe('CancelAssistEnemyTeam', self, self.OnCancelAssistEnemyTeam)
	
	-- self:OnQueueAssistEnemyTeam(player)
	Events:Subscribe('Player:Left', self, self.OnPlayerLeft)
	-- self:CheckQueueAssist()
	-- self:AssistTarget(player, isInQueueList)
	-- Endregion
	
	-- Region Squad stuff
	NetEvents:Subscribe('LeaveSquad', self, self.OnLeaveSquad)
	NetEvents:Subscribe('CreateSquad', self, self.OnCreateSquad)
	NetEvents:Subscribe('JoinSquad', self, self.OnJoinSquad)
		-- if player is SqLeader
	NetEvents:Subscribe('PrivateSquad', self, self.OnPrivateSquad)
	NetEvents:Subscribe('KickFromSquad', self, self.OnKickFromSquad)
	NetEvents:Subscribe('MakeSquadLeader', self, self.OnMakeSquadLeader)
	-- Endregion
	
	-- Region Admin Map Rotation
	--self:OnGetMapRotation()
	NetEvents:Subscribe('SetNextMap', self, self.OnSetNextMap)
	NetEvents:Subscribe('RunNextRound', self, self.OnRunNextRound)
	NetEvents:Subscribe('RestartRound', self, self.OnRestartRound)
	-- Endregion
	
	-- Region Admin Server Setup
	NetEvents:Subscribe('GetServerSetupSettings', self, self.OnGetServerSetupSettings)
	NetEvents:Subscribe('SaveServerSetupSettings', self, self.OnSaveServerSetupSettings)
	-- Endregion
	
	-- Region Manage Presets
	NetEvents:Subscribe('ManagePresets', self, self.OnManagePresets)
	-- self:PresetNormal()
	-- self:PresetHardcore()
	-- self:PresetInfantry()
	-- self:PresetHardcoreNoMap()
	-- self:PresetCustom(args)
	-- Endregion
	
	-- Region Manage ModSettings
	NetEvents:Subscribe('ResetModSettings', self, self.OnResetModSettings)
	NetEvents:Subscribe('ResetAndSaveModSettings', self, self.OnResetAndSaveModSettings)
	NetEvents:Subscribe('ApplyModSettings', self, self.OnApplyModSettings)
	NetEvents:Subscribe('SaveModSettings', self, self.OnSaveModSettings)
	-- Endregion
	
	-- Region ServerBanner on Loading Screen
		-- also Broadcast ServerSettings on every level loading
	Events:Subscribe('Level:Loaded', self, self.OnLevelLoaded)
	-- self:OnBroadcastServerInfo()
	Events:Subscribe('Level:Destroy', self, self.OnLevelDestroy)
	-- Endregion
	
	-- Region Send information to joining player (send serverInfo, send ServerBanner, if player is admin then send adminrights, 
		-- and check if we have an server owner)
		-- and check the assist queue
    Events:Subscribe('Player:Authenticated', self, self.OnAuthenticated)
	-- Endregion
end

-- Region String split method
	-- mostly for the adminList
function string:split(sep)
   local sep, fields = sep or " ", {}
   local pattern = string.format("([^%s]+)", sep)
   self:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end
-- Endregion

-- Region Vote stuff
	-- use reservedSlotsList for admin protection as soon as this get implemented
function BetterIngameAdmin:OnVotekickPlayer(player, votekickPlayer)
	if self.cooldownIsRunning == true then
		local args = {}
		args[1] = "Cooldown is running."
		args[2] = "Please wait ".. math.floor(self.cooldownBetweenVotes - self.cumulatedCooldownTime)  .." seconds and try again."
		NetEvents:SendTo('PopupResponse', player, args)
		return
	end	
	if self.voteInProgress == false then
		self.playerToVote = nil
		if PlayerManager:GetPlayerByName(votekickPlayer) ~= nil then
			self.playerToVote = PlayerManager:GetPlayerByName(votekickPlayer).name 
			if self.adminList[self.playerToVote] ~= nil and self.adminList[self.playerToVote].canKick ~= nil then
				-- That guy is admin and can Kick. So he is protected.
				local args = {}
				args[1] = "This player is protected."
				args[2] = "The player ".. votekickPlayer .." is protected and can not be voted off."
				NetEvents:SendTo('PopupResponse', player, args)
				print("VOTEKICK: Protection - Player " .. player.name .. " tried to votekick Admin " .. votekickPlayer)
				return
			elseif self.owner == self.playerToVote then
				-- That guy is the server owner. So he is protected.
				local args = {}
				args[1] = "This player is protected."
				args[2] = "The player ".. votekickPlayer .." is protected and can not be voted off."
				NetEvents:SendTo('PopupResponse', player, args)
				print("VOTEKICK: Protection - Player " .. player.name .. " tried to votekick Owner " .. votekickPlayer)
				return
			end
			if self.playerStartedVoteCounter[player.name] == nil then
				self.playerStartedVoteCounter[player.name] = 0
			end
			if self.playerStartedVoteCounter[player.name] < self.maxVotingStartsPerPlayer then
				self.playerStartedVoteCounter[player.name] = self.playerStartedVoteCounter[player.name] + 1
				NetEvents:Broadcast('Start:VotekickPlayer', votekickPlayer)
				table.insert(self.playersVotedYes, player.name)
				self.playersVotedYesCount = self.playersVotedYesCount + 1
				self.voteInProgress = true
				self.typeOfVote = "votekick"
				ChatManager:SendMessage(player.name .. " started a votekick on " .. self.playerToVote)
				print("VOTEKICK: Started - Player " .. player.name .. " started votekick on Player " .. votekickPlayer)
				if self.playerStartedVoteCounter[player.name] == self.maxVotingStartsPerPlayer then	
					NetEvents:SendTo('HideVoteButtons', player)
				end
			else
				local args = {}
				args[1] = "Votelimit reached."
				args[2] = "You reached the maximum amount of votes for this round."
				NetEvents:SendTo('PopupResponse', player, args)
			end
		end
	else
		local args = {}
		args[1] = "Vote in progress."
		args[2] = "Please wait until the current voting is over and try again."
		NetEvents:SendTo('PopupResponse', player, args)
	end
end

function BetterIngameAdmin:OnVotebanPlayer(player, votebanPlayer)
	if self.cooldownIsRunning == true then
		local args = {}
		args[1] = "Cooldown is running."
		args[2] = "Please wait ".. self.cooldownBetweenVotes - self.cumulatedCooldownTime  .." seconds and try again."
		NetEvents:SendTo('PopupResponse', player, args)
		return
	end	
	if self.voteInProgress == false then
		if PlayerManager:GetPlayerByName(votebanPlayer) ~= nil then
			self.playerToVote = PlayerManager:GetPlayerByName(votebanPlayer).name
			self.playerToVoteAccountGuid = PlayerManager:GetPlayerByName(votebanPlayer).accountGuid
			if self.adminList[self.playerToVote] ~= nil and self.adminList[self.playerToVote].canKick ~= nil then
				-- That guy is admin and can Kick. So he is protected.
				local args = {}
				args[1] = "This player is protected."
				args[2] = "The player ".. votebanPlayer .." is protected and can not be voted off."
				NetEvents:SendTo('PopupResponse', player, args)
				print("VOTEBAN: Protection - Player " .. player.name .. " tried to voteban Admin " .. votebanPlayer)
				return
			elseif self.owner == self.playerToVote then
				-- That guy is the server owner. So he is protected.
				local args = {}
				args[1] = "This player is protected."
				args[2] = "The player ".. votebanPlayer .." is protected and can not be voted off."
				NetEvents:SendTo('PopupResponse', player, args)
				print("VOTEBAN: Protection - Player " .. player.name .. " tried to voteban Owner " .. votebanPlayer)
				return
			end
			if self.playerStartedVoteCounter[player.name] == nil then
				self.playerStartedVoteCounter[player.name] = 0
			end
			if self.playerStartedVoteCounter[player.name] < self.maxVotingStartsPerPlayer then
				self.playerStartedVoteCounter[player.name] = self.playerStartedVoteCounter[player.name] + 1
				NetEvents:Broadcast('Start:VotebanPlayer', votebanPlayer)
				table.insert(self.playersVotedYes, player.name)
				self.playersVotedYesCount = self.playersVotedYesCount + 1
				self.voteInProgress = true
				self.typeOfVote = "voteban"
				ChatManager:SendMessage(player.name .. " started a voteban on " .. self.playerToVote)
				print("VOTEBAN: Started - Player " .. player.name .. " started voteban on Player " .. votebanPlayer)
				if self.playerStartedVoteCounter[player.name] == self.maxVotingStartsPerPlayer then	
					NetEvents:SendTo('HideVoteButtons', player)
				end
			else
				local args = {}
				args[1] = "Votelimit reached."
				args[2] = "You reached the maximum amount of votes for this round."
				NetEvents:SendTo('PopupResponse', player, args)
			end
		end
	else
		local args = {}
		args[1] = "Vote in progress."
		args[2] = "Please wait until the current voting is over and try again."
		NetEvents:SendTo('PopupResponse', player, args)
	end
end

function BetterIngameAdmin:OnSurrender(player)
	if self.cooldownIsRunning == true then
		local args = {}
		args[1] = "Cooldown is running."
		args[2] = "Please wait ".. self.cooldownBetweenVotes - self.cumulatedCooldownTime  .." seconds and try again."
		NetEvents:SendTo('PopupResponse', player, args)
		return
	end	
	if self.voteInProgress == false then
		if player.teamId == TeamId.Team1 then
			self.typeOfVote = "surrenderUS"
		else
			self.typeOfVote = "surrenderRU"
		end
		if self.playerStartedVoteCounter[player.name] == nil then
			self.playerStartedVoteCounter[player.name] = 0
		end
		if self.playerStartedVoteCounter[player.name] < self.maxVotingStartsPerPlayer then
			NetEvents:Broadcast('Start:Surrender', self.typeOfVote)
			table.insert(self.playersVotedYes, player.name)
			self.playersVotedYesCount = self.playersVotedYesCount + 1
			self.voteInProgress = true
			ChatManager:SendMessage(player.name .. " started a surrender voting")
			print("VOTE SURRENDER: Started - Player " .. player.name .. " started a surrender voting for the team " .. player.TeamId)
			if self.playerStartedVoteCounter[player.name] == self.maxVotingStartsPerPlayer then	
				NetEvents:SendTo('HideVoteButtons', player)
			end
		else
			local args = {}
			args[1] = "Votelimit reached."
			args[2] = "You reached the maximum amount of votes for this round."
			NetEvents:SendTo('PopupResponse', player, args)
		end
	else
		local args = {}
		args[1] = "Vote in progress."
		args[2] = "Please wait until the current voting is over and try again."
		NetEvents:SendTo('PopupResponse', player, args)
	end
end

function BetterIngameAdmin:OnCheckVoteYes(player)
	for i,playerName in pairs(self.playersVotedYes) do
		if playerName == player.name then
			return
		end
	end
	for i,playerName in pairs(self.playersVotedNo) do
		if playerName == player.name then
			table.remove(self.playersVotedNo, i)
			self.playersVotedNoCount = self.playersVotedNoCount - 1
			NetEvents:Broadcast('Remove:OneNoVote')
		end
	end
	table.insert(self.playersVotedYes, player.name)
	self.playersVotedYesCount = self.playersVotedYesCount + 1
	NetEvents:Broadcast('Vote:Yes')
end

function BetterIngameAdmin:OnCheckVoteNo(player)
	for i,playerName in pairs(self.playersVotedNo) do
		if playerName == player.name then
			return
		end
	end
	for i,playerName in pairs(self.playersVotedYes) do
		if playerName == player.name then
			table.remove(self.playersVotedYes, i)
			self.playersVotedYesCount = self.playersVotedYesCount - 1
			NetEvents:Broadcast('Remove:OneYesVote')
		end
	end
	table.insert(self.playersVotedNo, player.name)
	self.playersVotedNoCount = self.playersVotedNoCount + 1
	NetEvents:Broadcast('Vote:No')
end

function BetterIngameAdmin:OnEngineUpdate(deltaTime, simulationDeltaTime)
	if self.voteInProgress == true then
		self.cumulatedTime = self.cumulatedTime + deltaTime
		if self.cumulatedTime >= self.voteDuration + 1 then
			self:EndVote()
		end
	end
	self.cumulatedTimeForPing = self.cumulatedTimeForPing + deltaTime
	if self.cumulatedTimeForPing >= 5 then
		local pingTable = {}
		for i,player in pairs(PlayerManager:GetPlayers()) do
			pingTable[player.name] = player.ping
			table.insert(pingTable, pingplayer)
		end
		self.cumulatedTimeForPing = 0
		NetEvents:Broadcast('Player:Ping', pingTable)
	end
	if self.cooldownIsRunning == true then
		self.cumulatedCooldownTime = self.cumulatedCooldownTime + deltaTime
		if self.cooldownBetweenVotes <= self.cumulatedCooldownTime then
			self.cumulatedCooldownTime = 0
			self.cooldownIsRunning = false
		end
	end
end

function BetterIngameAdmin:EndVote()
	if self.playersVotedYesCount > self.playersVotedNoCount and self.playersVotedYesCount >= 4 then
		if (self.playersVotedYesCount + self.playersVotedNoCount) >= (TeamSquadManager:GetTeamPlayerCount(TeamId.Team1) * self.votingParticipationNeeded / 100) and self.typeOfVote == "surrenderUS" then
			args = {"2"}
			RCON:SendCommand('mapList.endround', args)
			print("VOTE SURRENDER: Success - The US team surrenders. RESULT - YES: " .. self.playersVotedYesCount .. " Players | NO: " .. self.playersVotedNoCount .. " Players.")
		elseif (self.playersVotedYesCount + self.playersVotedNoCount) >= (TeamSquadManager:GetTeamPlayerCount(TeamId.Team2) * self.votingParticipationNeeded / 100) and self.typeOfVote == "surrenderRU" then
			args = {"1"}
			RCON:SendCommand('mapList.endround', args)
			print("VOTE SURRENDER: Success - The RU team surrenders. RESULT - YES: " .. self.playersVotedYesCount .. " Players | NO: " .. self.playersVotedNoCount .. " Players.")
		elseif (self.playersVotedYesCount + self.playersVotedNoCount) >= (PlayerManager:GetPlayerCount()  * self.votingParticipationNeeded / 100) then
			if (self.typeOfVote == "votekick" or self.typeOfVote == "voteban") and self.playerToVote ~= nil then
				local votedPlayer = PlayerManager:GetPlayerByName(self.playerToVote)
				if self.typeOfVote == "votekick" and votedPlayer ~= nil then
					votedPlayer:Kick("Votekick")
					print("VOTEKICK: Success - The Player " .. self.playerToVote .. " got kicked. RESULT - YES: " .. self.playersVotedYesCount .. " Players | NO: " .. self.playersVotedNoCount .. " Players.")
				elseif self.typeOfVote == "voteban" then
					RCON:SendCommand('banList.add', {"guid", tostring(self.playerToVoteAccountGuid), "seconds", "86400", "Voteban: 24 hours"})
					print("VOTEBAN: Success - The Player " .. self.playerToVote .. " got banned for 24 hours. RESULT - YES: " .. self.playersVotedYesCount .. " Players | NO: " .. self.playersVotedNoCount .. " Players.")
				end
			end
		else
			if self.typeOfVote == "votekick" then
				print("VOTEKICK: Failed - Not enough players voted. RESULT - YES: " .. self.playersVotedYesCount .. " Players | NO: " .. self.playersVotedNoCount .. " Players.")
			elseif self.typeOfVote == "voteban" then
				print("VOTEBAN: Failed - Not enough players voted. RESULT - YES: " .. self.playersVotedYesCount .. " Players | NO: " .. self.playersVotedNoCount .. " Players.")
			elseif self.typeOfVote == "surrenderRU" then
				print("VOTE SURRENDER RU: Failed - Not enough players voted. RESULT - YES: " .. self.playersVotedYesCount .. " Players | NO: " .. self.playersVotedNoCount .. " Players.")
			elseif self.typeOfVote == "surrenderUS" then
				print("VOTE SURRENDER US: Failed - Not enough players voted. RESULT - YES: " .. self.playersVotedYesCount .. " Players | NO: " .. self.playersVotedNoCount .. " Players.")
			end
		end
	else
		if self.typeOfVote == "votekick" then
			print("VOTEKICK: Failed - Not enough players voted with yes. RESULT - YES: " .. self.playersVotedYesCount .. " Players | NO: " .. self.playersVotedNoCount .. " Players.")
		elseif self.typeOfVote == "voteban" then
			print("VOTEBAN: Failed - Not enough players voted with yes. RESULT - YES: " .. self.playersVotedYesCount .. " Players | NO: " .. self.playersVotedNoCount .. " Players.")
		elseif self.typeOfVote == "surrenderRU" then
			print("VOTE SURRENDER RU: Failed - Not enough players voted with yes. RESULT - YES: " .. self.playersVotedYesCount .. " Players | NO: " .. self.playersVotedNoCount .. " Players.")
		elseif self.typeOfVote == "surrenderUS" then
			print("VOTE SURRENDER US: Failed - Not enough players voted with yes. RESULT - YES: " .. self.playersVotedYesCount .. " Players | NO: " .. self.playersVotedNoCount .. " Players.")
		end
	end
	self.playersVotedYesCount = 0
	self.playersVotedNoCount = 0
	self.playersVotedYes = {}
	self.playersVotedNo = {}
	self.playerToVote = nil
	self.playerToVoteAccountGuid = nil
	self.voteInProgress = false
	self.cumulatedTime = 0
	self.typeOfVote = ""
	self.cooldownIsRunning = true
end
-- Endregion

-- Region Admin gameAdmin Events Dispatch/ Subscribe
function BetterIngameAdmin:OnGameAdminPlayer(playerName, abilitities)
	self.adminList[playerName] = abilitities
	local player = PlayerManager:GetPlayerByName(playerName)
	if player ~= nil then
		NetEvents:SendTo('AdminPlayer', player, abilitities)
	end
end

function BetterIngameAdmin:OnGameAdminClear()
	for adminName,abilitities in pairs(self.adminList) do
		local admin = PlayerManager:GetPlayerByName(adminName)
		if admin ~= nil then
			NetEvents:SendTo('AdminPlayer', player)
		end
	end
	self.adminList = {}
end
-- Endregion

-- Region Admin actions for players
function BetterIngameAdmin:OnMovePlayer(player, args)
	local messages = {}
	if (self.adminList[player.name] == nil or self.adminList[player.name].canMovePlayers == nil) and self.owner ~= player.name then
		-- That guy is no admin or doesn't have that ability. That guy is also not the server owner.
		messages[1] = "Error."
		messages[2] = "Sorry, you are no admin or at least don't have the required abilitities to do this action."
		NetEvents:SendTo('PopupResponse', player, messages)
		print("ADMIN MOVE - Error Player " .. player.name .. " is no admin")
		return
	end
	local targetPlayer = PlayerManager:GetPlayerByName(args[1])
	if targetPlayer == nil then
		-- Player not found.
		messages = {}
		messages[1] = "Error."
		messages[2] = "Sorry, we couldn't find the player."
		NetEvents:SendTo('PopupResponse', player, messages)
		print("ADMIN MOVE - Error Admin " .. player.name .. " tried to move Player " .. targetPlayer.name .. " but we couldn't find him.")
		return
	end
	RCON:SendCommand('admin.movePlayer', {targetPlayer.name, args[2], args[3], "true"})
	RCON:SendCommand('squad.private', {tostring(targetPlayer.teamId), tostring(targetPlayer.squadId), "false"})
	if args[4] ~= nil and args[4] ~= "" then
		messages = {}
		messages[1] = "Moved by admin."
		messages[2] = "You got moved by an admin. Reason: ".. args[4]
		NetEvents:SendTo('PopupResponse', targetPlayer, messages)
		print("ADMIN MOVE - Admin " .. player.name .. " moved Player " .. targetPlayer.name .. " to the team " .. args[2] .. " and the squad " .. args[3] .. ". Reason: " .. args[4])
	else
		-- send confirm to player and message to target
		messages[1] = "Moved by admin."
		messages[2] = "You got moved by an admin."
		NetEvents:SendTo('PopupResponse', targetPlayer, messages)
		messages = {}
		messages[1] = "Move confirmed."
		messages[2] = "You moved the player ".. targetPlayer.name .." successfully."
		NetEvents:SendTo('PopupResponse', player, messages)
		print("ADMIN MOVE - Admin " .. player.name .. " moved Player " .. targetPlayer.name .. " to the team " .. args[2] .. " and the squad " .. args[3] .. ".")
	end
end

function BetterIngameAdmin:OnKillPlayer(player, args)
	local messages = {}
	if (self.adminList[player.name] == nil or self.adminList[player.name].canKillPlayers == nil) and self.owner ~= player.name then
		-- That guy is no admin or doesn't have that ability. That guy is also not the server owner.
		messages[1] = "Error."
		messages[2] = "Sorry, you are no admin or at least don't have the required abilitities to do this action."
		NetEvents:SendTo('PopupResponse', player, messages)
		print("ADMIN KILL - Error Player " .. player.name .. " is no admin")
		return
	end
	local targetPlayer = PlayerManager:GetPlayerByName(args[1])
	if targetPlayer == nil then
		-- Player not found.
		messages = {}
		messages[1] = "Error."
		messages[2] = "Sorry, we couldn't find the player."
		NetEvents:SendTo('PopupResponse', player, messages)
		print("ADMIN KILL - Error Admin " .. player.name .. " tried to kill Player " .. targetPlayer.name .. " but we couldn't find him.")
		return
	end
	if targetPlayer.alive == true then
		RCON:SendCommand('admin.killPlayer', {targetPlayer.name})
		if args[2] ~= nil then
			RCON:SendCommand('admin.say', {"Reason for kill: "..args[2], "player", targetPlayer.name})
			print("ADMIN KILL - Admin " .. player.name .. " killed Player " .. targetPlayer.name .. ". Reason: " .. args[2])
		else
			print("ADMIN KILL - Admin " .. player.name .. " killed Player " .. targetPlayer.name .. ".")
		end
	elseif player.corpse ~= nil and player.corpse.isDead == false then
		targetPlayer.corpse:ForceDead()
		if args[2] ~= nil and args[2] ~= "" then
			RCON:SendCommand('admin.say', {"Reason for kill: "..args[2], "player", targetPlayer.name})
			print("ADMIN KILL - Admin " .. player.name .. " killed Player " .. targetPlayer.name .. ". Reason: " .. args[2])
		else
			print("ADMIN KILL - Admin " .. player.name .. " killed Player " .. targetPlayer.name .. ".")
		end
	else
		-- TargetPlayer aready dead.
		messages[1] = "Error."
		messages[2] = "The player".. targetPlayer.name .." is already dead."
		NetEvents:SendTo('PopupResponse', player, messages)
		print("ADMIN KILL - Error Admin " .. player.name .. " tried to kill Player " .. targetPlayer.name .. " but he is already dead.")
	end
end

function BetterIngameAdmin:OnKickPlayer(player, args)
	local messages = {}
	if (self.adminList[player.name] == nil or self.adminList[player.name].canKickPlayers == nil) and self.owner ~= player.name then
		-- That guy is no admin or doesn't have that ability. That guy is also not the server owner.
		messages[1] = "Error."
		messages[2] = "Sorry, you are no admin or at least don't have the required abilitities to do this action."
		NetEvents:SendTo('PopupResponse', player, messages)
		print("ADMIN KICK - Error Player " .. player.name .. " is no admin")
		return
	end
	local targetPlayer = PlayerManager:GetPlayerByName(args[1])
	if targetPlayer == nil then
		-- Player not found.
		messages = {}
		messages[1] = "Error."
		messages[2] = "Sorry, we couldn't find the player."
		NetEvents:SendTo('PopupResponse', player, messages)
		print("ADMIN KICK - Error Admin " .. player.name .. " tried to kick Player " .. targetPlayer.name .. " but we couldn't find him.")
		return
	end
	if args[2]~= nil and args[2] ~= "" then
		print("ADMIN KICK - Admin " .. player.name .. " kicked Player " .. targetPlayer.name .. ". Reason: " .. args[2])
		targetPlayer:Kick(""..args[2].." (".. player.name..")")
	else
		print("ADMIN KICK - Admin " .. player.name .. " kicked Player " .. targetPlayer.name .. ".")
		targetPlayer:Kick("Kicked by ".. player.name.."")
	end
	messages = {}
	messages[1] = "Kick confirmed."
	messages[2] = "You kicked the player ".. targetPlayer.name .." successfully."
	NetEvents:SendTo('PopupResponse', player, messages)
end

function BetterIngameAdmin:OnTBanPlayer(player, args)
	local messages = {}
	if (self.adminList[player.name] == nil or self.adminList[player.name].canTemporaryBanPlayers == nil) and self.owner ~= player.name then
		-- That guy is no admin or doesn't have that ability. That guy is also not the server owner.
		messages[1] = "Error."
		messages[2] = "Sorry, you are no admin or at least don't have the required abilitities to do this action."
		NetEvents:SendTo('PopupResponse', player, messages)
		print("ADMIN TBAN - Error Player " .. player.name .. " is no admin")
		return
	end
	local targetPlayer = PlayerManager:GetPlayerByName(args[1])
	if targetPlayer == nil then
		-- Player not found.
		messages = {}
		messages[1] = "Error."
		messages[2] = "Sorry, we couldn't find the player."
		NetEvents:SendTo('PopupResponse', player, messages)
		print("ADMIN TBAN - Error Admin " .. player.name .. " tried to temp. ban Player " .. targetPlayer.name .. " but we couldn't find him.")
		return
	end
	if args[3]~= nil and args[3] ~= "" then
		print("ADMIN TBAN - Admin " .. player.name .. " temp. banned Player " .. targetPlayer.name .. "for " .. args[2] .. " minutes. Reason: " .. args[3])
		targetPlayer:BanTemporarily(args[2]*60, ""..args[3].." (".. player.name..") "..args[2].." minutes")
	else
		print("ADMIN TBAN - Admin " .. player.name .. " temp. banned Player " .. targetPlayer.name .. "for " .. args[2] .. " minutes.")
		targetPlayer:BanTemporarily(args[2]*60, "Temporarily banned by ".. player.name.." for "..args[2].." minutes")
	end
	messages = {}
	messages[1] = "Ban confirmed."
	messages[2] = "You banned the player ".. targetPlayer.name .." successfully for ".. args[2] .." minutes."
	NetEvents:SendTo('PopupResponse', player, messages)
end

function BetterIngameAdmin:OnBanPlayer(player, args)
	local messages = {}
	if (self.adminList[player.name] == nil or self.adminList[player.name].canPermanentlyBanPlayers == nil) and self.owner ~= player.name then
		-- That guy is no admin or doesn't have that ability. That guy is also not the server owner.
		messages[1] = "Error."
		messages[2] = "Sorry, you are no admin or at least don't have the required abilitities to do this action."
		NetEvents:SendTo('PopupResponse', player, messages)
		print("ADMIN BAN - Error Player " .. player.name .. " is no admin")
		return
	end
	local targetPlayer = PlayerManager:GetPlayerByName(args[1])
	if targetPlayer == nil then
		-- Player not found.
		messages = {}
		messages[1] = "Error."
		messages[2] = "Sorry, we couldn't find the player."
		NetEvents:SendTo('PopupResponse', player, messages)
		print("ADMIN BAN - Error Admin " .. player.name .. " tried to ban Player " .. targetPlayer.name .. " but we couldn't find him.")
		return
	end
	if args[2]~= nil and args[2] ~= "" then
		print("ADMIN BAN - Admin " .. player.name .. " banned Player " .. targetPlayer.name .. ". Reason: " .. args[2])
		targetPlayer:Ban(""..args[2].." (".. player.name..")")
	else
		print("ADMIN BAN - Admin " .. player.name .. " banned Player " .. targetPlayer.name .. ".")
		targetPlayer:Ban("Banned by ".. player.name.."")
	end
	messages = {}
	messages[1] = "Ban confirmed."
	messages[2] = "You banned the player ".. targetPlayer.name .." successfully."
	NetEvents:SendTo('PopupResponse', player, messages)
end

function BetterIngameAdmin:OnDeleteAdminRights(player, args)
	local messages = {}
	if (self.adminList[player.name] == nil or self.adminList[player.name].canEditGameAdminList == nil) and self.owner ~= player.name then
		-- That guy is no admin or doesn't have that ability. That guy is also not the server owner.
		messages[1] = "Error."
		messages[2] = "Sorry, you are no admin or at least don't have the required abilitities to do this action."
		NetEvents:SendTo('PopupResponse', player, messages)
		print("ADMIN - ADMIN RIGHTS - DELETE - Error Player " .. player.name .. " is no admin")
		return
	end
	RCON:SendCommand('gameAdmin.remove', args)
end

function BetterIngameAdmin:OnDeleteAndSaveAdminRights(player, args)
	local messages = {}
	if (self.adminList[player.name] == nil or self.adminList[player.name].canEditGameAdminList == nil) and self.owner ~= player.name then
		-- That guy is no admin or doesn't have that ability. That guy is also not the server owner.
		messages[1] = "Error."
		messages[2] = "Sorry, you are no admin or at least don't have the required abilitities to do this action."
		NetEvents:SendTo('PopupResponse', player, messages)
		print("ADMIN - ADMIN RIGHTS - DELETE AND SAVE - Error Player " .. player.name .. " is no admin")
		return
	end
	RCON:SendCommand('gameAdmin.remove', args)
	RCON:SendCommand('gameAdmin.save')
end

function BetterIngameAdmin:OnUpdateAdminRights(player, args)
	local messages = {}
	if (self.adminList[player.name] == nil or self.adminList[player.name].canEditGameAdminList == nil) and self.owner ~= player.name then
		-- That guy is no admin or doesn't have that ability. That guy is also not the server owner.
		messages[1] = "Error."
		messages[2] = "Sorry, you are no admin or at least don't have the required abilitities to do this action."
		NetEvents:SendTo('PopupResponse', player, messages)
		print("ADMIN - ADMIN RIGHTS - ADD/ UPDATE - Error Player " .. player.name .. " is no admin")
		return
	end
	RCON:SendCommand('gameAdmin.add', args)
end

function BetterIngameAdmin:OnUpdateAndSaveAdminRights(player, args)
	local messages = {}
	if (self.adminList[player.name] == nil or self.adminList[player.name].canEditGameAdminList == nil) and self.owner ~= player.name then
		-- That guy is no admin or doesn't have that ability. That guy is also not the server owner.
		messages[1] = "Error."
		messages[2] = "Sorry, you are no admin or at least don't have the required abilitities to do this action."
		NetEvents:SendTo('PopupResponse', player, messages)
		print("ADMIN - ADMIN RIGHTS - ADD/ UPDATE AND SAVE - Error Player " .. player.name .. " is no admin")
		return
	end
	RCON:SendCommand('gameAdmin.add', args)
	RCON:SendCommand('gameAdmin.save')
end

function BetterIngameAdmin:OnGetAdminRightsOfPlayer(player, playerName)
	local found = false
	local targetPlayer = PlayerManager:GetPlayerByName(playerName)
	if targetPlayer == nil then
		-- That player left.
		local messages = {}
		messages[1] = "Error."
		messages[2] = "Sorry, we couldn't find the player."
		NetEvents:SendTo('PopupResponse', player, messages)
		return
	end
	NetEvents:SendTo('AdminRightsOfPlayer', player, self.adminList[targetPlayer.name])
end
-- Endregion

-- Region Player Assist enemy team
function BetterIngameAdmin:OnAssistEnemyTeam(player)
	--print("ASSIST - Player " .. player.name .. " want to assist the enemy team.")
	if self.enableAssistFunction == true then
		self:AssistTarget(player, 0)
	else
		local messages = {}
		messages[1] = "Assist Deactivated."
		messages[2] = "Sorry, we couldn't switch you. The assist function is currently deactivated."
		NetEvents:SendTo('PopupResponse', player, messages)
	end
end

function BetterIngameAdmin:OnQueueAssistEnemyTeam(player)
	local messages = {}
	messages[1] = "Assist Queue."
	messages[2] = "Sorry, we couldn't switch you. We will switch you when it is possible. You are now in the Assist Queue."
	NetEvents:SendTo('PopupResponse', player, messages)
	print("ASSIST - QUEUE - Player " .. player.name .. " is now in the assist queue.")
	
	if player.teamId == TeamId.Team1 then
		table.insert(self.queueAssistList1, player.name)
	elseif player.teamId == TeamId.Team2 then
		table.insert(self.queueAssistList2, player.name)
	elseif player.teamId == TeamId.Team3 then
		table.insert(self.queueAssistList3, player.name)
	else
		table.insert(self.queueAssistList4, player.name)
	end
end

function BetterIngameAdmin:OnPlayerLeft(player)
	if self.enableAssistFunction == true then
		self:CheckQueueAssist()
	end
end

function BetterIngameAdmin:CheckQueueAssist()
	::continue1::
	if self.queueAssistList1[1] ~= nil then
		local player = PlayerManager:GetPlayerByName(self.queueAssistList1[1])
		if player == nil then
			table.remove(self.queueAssistList1, 1)
			goto continue1
		end
		self:AssistTarget(player, 1)
	end
	::continue2::
	if self.queueAssistList2[1] ~= nil then
		local player = PlayerManager:GetPlayerByName(self.queueAssistList2[1])
		if player == nil then
			table.remove(self.queueAssistList2, 1)
			goto continue2
		end
		self:AssistTarget(player, 2)
	end
	::continue3::
	if self.queueAssistList3[1] ~= nil then
		local player = PlayerManager:GetPlayerByName(self.queueAssistList3[1])
		if player == nil then
			table.remove(self.queueAssistList3, 1)
			goto continue3
		end
		self:AssistTarget(player, 3)
	end
	::continue4::
	if self.queueAssistList4[1] ~= nil then
		local player = PlayerManager:GetPlayerByName(self.queueAssistList4[1])
		if player == nil then
			table.remove(self.queueAssistList4, 1)
			goto continue4
		end
		self:AssistTarget(player, 4)
	end
end

function BetterIngameAdmin:AssistTarget(player, isInQueueList)
	local currentTeamCount = 0
	local enemyTeamCount = 0
	local currentTeamTickets = 0
	local enemyTeamTickets = 0
	local enemyTeam1Count = 0
	local enemyTeam2Count = 0
	local enemyTeam3Count = 0
	local enemyTeam1Tickets = 0
	local enemyTeam2Tickets = 0
	local enemyTeam3Tickets = 0
	local currentTeam = 0
	local enemyTeam1 = 0
	local enemyTeam2 = 0
	local enemyTeam3 = 0
	local gameMode = SharedUtils:GetCurrentGameMode()
	if gameMode ~= "SquadDeathMatch0" then		
		if player.teamId == TeamId.Team1 then
			currentTeamCount = TeamSquadManager:GetTeamPlayerCount(TeamId.Team1)
			enemyTeamCount = TeamSquadManager:GetTeamPlayerCount(TeamId.Team2)
			currentTeamTickets = TicketManager:GetTicketCount(TeamId.Team1)
			enemyTeamTickets = TicketManager:GetTicketCount(TeamId.Team2)
		else
			currentTeamCount = TeamSquadManager:GetTeamPlayerCount(TeamId.Team2)
			enemyTeamCount = TeamSquadManager:GetTeamPlayerCount(TeamId.Team1)
			currentTeamTickets = TicketManager:GetTicketCount(TeamId.Team2)
			enemyTeamTickets = TicketManager:GetTicketCount(TeamId.Team1)
		end
		if currentTeamCount > (enemyTeamCount + 1) or (currentTeamTickets >= enemyTeamTickets and currentTeamCount > (enemyTeamCount - 2)) then
			if player.alive == true then
				RCON:SendCommand('admin.killPlayer', {player.name})
			end
			if player.teamId == TeamId.Team1 then
				player.teamId = TeamId.Team2
			else
				player.teamId = TeamId.Team1
			end
			if isInQueueList == 1 then
				table.remove(self.queueAssistList1, 1)
			elseif isInQueueList == 2 then
				table.remove(self.queueAssistList2, 1)
			end
			local messages = {}
			messages[1] = "Assist Enemy Team."
			messages[2] = "You have been switched because of your assist request."
			NetEvents:SendTo('PopupResponse', player, messages)
			print("ASSIST - MOVE - Player " .. player.name .. " is now helping the enemy team " .. player.teamId .. ".")
		else
			if isInQueueList == 0 then
				self:QuickSwitch(player)
			end
		end
	else
		if player.teamId == TeamId.Team1 then
			currentTeamCount = TeamSquadManager:GetTeamPlayerCount(TeamId.Team1)
			enemyTeam1Count = TeamSquadManager:GetTeamPlayerCount(TeamId.Team2)
			enemyTeam2Count = TeamSquadManager:GetTeamPlayerCount(TeamId.Team3)
			enemyTeam3Count = TeamSquadManager:GetTeamPlayerCount(TeamId.Team4)
			currentTeamTickets = TicketManager:GetTicketCount(TeamId.Team1)
			enemyTeam1Tickets = TicketManager:GetTicketCount(TeamId.Team2)
			enemyTeam2Tickets = TicketManager:GetTicketCount(TeamId.Team3)
			enemyTeam3Tickets = TicketManager:GetTicketCount(TeamId.Team4)
			currentTeam = TeamId.Team1
			enemyTeam1 = TeamId.Team2
			enemyTeam2 = TeamId.Team3
			enemyTeam3 = TeamId.Team4
		elseif player.teamId == TeamId.Team2 then
			currentTeamCount = TeamSquadManager:GetTeamPlayerCount(TeamId.Team2)
			enemyTeam1Count = TeamSquadManager:GetTeamPlayerCount(TeamId.Team1)
			enemyTeam2Count = TeamSquadManager:GetTeamPlayerCount(TeamId.Team3)
			enemyTeam3Count = TeamSquadManager:GetTeamPlayerCount(TeamId.Team4)
			currentTeamTickets = TicketManager:GetTicketCount(TeamId.Team2)
			enemyTeam1Tickets = TicketManager:GetTicketCount(TeamId.Team1)
			enemyTeam2Tickets = TicketManager:GetTicketCount(TeamId.Team3)
			enemyTeam3Tickets = TicketManager:GetTicketCount(TeamId.Team4)
			currentTeam = TeamId.Team2
			enemyTeam1 = TeamId.Team1
			enemyTeam2 = TeamId.Team3
			enemyTeam3 = TeamId.Team4
		elseif player.teamId == TeamId.Team3 then
			currentTeamCount = TeamSquadManager:GetTeamPlayerCount(TeamId.Team3)
			enemyTeam1Count = TeamSquadManager:GetTeamPlayerCount(TeamId.Team1)
			enemyTeam2Count = TeamSquadManager:GetTeamPlayerCount(TeamId.Team2)
			enemyTeam3Count = TeamSquadManager:GetTeamPlayerCount(TeamId.Team4)
			currentTeamTickets = TicketManager:GetTicketCount(TeamId.Team3)
			enemyTeam1Tickets = TicketManager:GetTicketCount(TeamId.Team1)
			enemyTeam2Tickets = TicketManager:GetTicketCount(TeamId.Team2)
			enemyTeam3Tickets = TicketManager:GetTicketCount(TeamId.Team4)
			currentTeam = TeamId.Team3
			enemyTeam1 = TeamId.Team1
			enemyTeam2 = TeamId.Team2
			enemyTeam3 = TeamId.Team4
		else
			currentTeamCount = TeamSquadManager:GetTeamPlayerCount(TeamId.Team4)
			enemyTeam1Count = TeamSquadManager:GetTeamPlayerCount(TeamId.Team1)
			enemyTeam2Count = TeamSquadManager:GetTeamPlayerCount(TeamId.Team2)
			enemyTeam3Count = TeamSquadManager:GetTeamPlayerCount(TeamId.Team3)
			currentTeamTickets = TicketManager:GetTicketCount(TeamId.Team4)
			enemyTeam1Tickets = TicketManager:GetTicketCount(TeamId.Team1)
			enemyTeam2Tickets = TicketManager:GetTicketCount(TeamId.Team2)
			enemyTeam3Tickets = TicketManager:GetTicketCount(TeamId.Team3)
			currentTeam = TeamId.Team4
			enemyTeam1 = TeamId.Team1
			enemyTeam2 = TeamId.Team2
			enemyTeam3 = TeamId.Team3
		end
		if currentTeamCount > (enemyTeam1Count + 1) or (currentTeamTickets >= enemyTeam1Tickets and currentTeamCount > (enemyTeam1Count - 2)) then
			if player.alive == true then
				RCON:SendCommand('admin.killPlayer', {player.name})
			end
			player.teamId = enemyTeam1
			if isInQueueList == 1 then
				table.remove(self.queueAssistList1, 1)
			elseif isInQueueList == 2 then
				table.remove(self.queueAssistList2, 1)
			elseif isInQueueList == 3 then
				table.remove(self.queueAssistList3, 1)
			elseif isInQueueList == 4 then
				table.remove(self.queueAssistList4, 1)
			end
			local messages = {}
			messages[1] = "Assist Enemy Team."
			messages[2] = "You have been switched because of your assist request."
			NetEvents:SendTo('PopupResponse', player, messages)
			print("ASSIST - MOVE - Player " .. player.name .. " is now helping the enemy team " .. player.teamId .. ".")
		elseif currentTeamCount > (enemyTeam2Count + 1) or (currentTeamTickets >= enemyTeam2Tickets and currentTeamCount > (enemyTeam2Count - 2)) then
			if player.alive == true then
				RCON:SendCommand('admin.killPlayer', {player.name})
			end
			player.teamId = enemyTeam2
			if isInQueueList == 1 then
				table.remove(self.queueAssistList1, 1)
			elseif isInQueueList == 2 then
				table.remove(self.queueAssistList2, 1)
			elseif isInQueueList == 3 then
				table.remove(self.queueAssistList3, 1)
			elseif isInQueueList == 4 then
				table.remove(self.queueAssistList4, 1)
			end
			local messages = {}
			messages[1] = "Assist Enemy Team."
			messages[2] = "You have been switched because of your assist request."
			NetEvents:SendTo('PopupResponse', player, messages)
			print("ASSIST - MOVE - Player " .. player.name .. " is now helping the enemy team " .. player.teamId .. ".")
		elseif currentTeamCount > (enemyTeam3Count + 1) or (currentTeamTickets >= enemyTeam3Tickets and currentTeamCount > (enemyTeam3Count - 2)) then
			if player.alive == true then
				RCON:SendCommand('admin.killPlayer', {player.name})
			end
			player.teamId = enemyTeam3
			if isInQueueList == 1 then
				table.remove(self.queueAssistList1, 1)
			elseif isInQueueList == 2 then
				table.remove(self.queueAssistList2, 1)
			elseif isInQueueList == 3 then
				table.remove(self.queueAssistList3, 1)
			elseif isInQueueList == 4 then
				table.remove(self.queueAssistList4, 1)
			end
			local messages = {}
			messages[1] = "Assist Enemy Team."
			messages[2] = "You have been switched because of your assist request."
			NetEvents:SendTo('PopupResponse', player, messages)
			print("ASSIST - MOVE - Player " .. player.name .. " is now helping the enemy team " .. player.teamId .. ".")
		else
			if isInQueueList == 0 then
				self:QuickSwitch(player)
			end
		end
	end
end

function BetterIngameAdmin:QuickSwitch(player)
	local playerTeamId = player.teamId
	local listPlayer = nil
	if player.teamId == TeamId.Team1 then
		::continue2::
		if self.queueAssistList2[1] ~= nil then
			listPlayer = PlayerManager:GetPlayerByName(self.queueAssistList2[1])
			if listPlayer == nil then
				table.remove(self.queueAssistList2, 1)
				goto continue2
			end
			if listPlayer.alive == true then
				RCON:SendCommand('admin.killPlayer', {listPlayer.name})
			end
			if player.alive == true then
				RCON:SendCommand('admin.killPlayer', {player.name})
			end
			listPlayer.teamId = TeamId.Team1
			player.teamId = TeamId.Team2
			table.remove(self.queueAssistList2, 1)
		end
		::continue3::
		if self.queueAssistList3[1] ~= nil then
			listPlayer = PlayerManager:GetPlayerByName(self.queueAssistList3[1])
			if listPlayer == nil then
				table.remove(self.queueAssistList3, 1)
				goto continue3
			end
			if listPlayer.alive == true then
				RCON:SendCommand('admin.killPlayer', {listPlayer.name})
			end
			if player.alive == true then
				RCON:SendCommand('admin.killPlayer', {player.name})
			end
			listPlayer.teamId = TeamId.Team1
			player.teamId = TeamId.Team3
			table.remove(self.queueAssistList3, 1)
		end
		::continue4::
		if self.queueAssistList4[1] ~= nil then
			listPlayer = PlayerManager:GetPlayerByName(self.queueAssistList4[1])
			if listPlayer == nil then
				table.remove(self.queueAssistList4, 1)
				goto continue4
			end
			if listPlayer.alive == true then
				RCON:SendCommand('admin.killPlayer', {listPlayer.name})
			end
			if player.alive == true then
				RCON:SendCommand('admin.killPlayer', {player.name})
			end
			listPlayer.teamId = TeamId.Team1
			player.teamId = TeamId.Team4
			table.remove(self.queueAssistList4, 1)
		end
	elseif player.teamId == TeamId.Team2 then
		::continue1::
		if self.queueAssistList1[1] ~= nil then
			listPlayer = PlayerManager:GetPlayerByName(self.queueAssistList1[1])
			if listPlayer == nil then
				table.remove(self.queueAssistList1, 1)
				goto continue1
			end
			if listPlayer.alive == true then
				RCON:SendCommand('admin.killPlayer', {listPlayer.name})
			end
			if player.alive == true then
				RCON:SendCommand('admin.killPlayer', {player.name})
			end
			listPlayer.teamId = TeamId.Team2
			player.teamId = TeamId.Team1
			table.remove(self.queueAssistList1, 1)
		end
		::continue3::
		if self.queueAssistList3[1] ~= nil then
			listPlayer = PlayerManager:GetPlayerByName(self.queueAssistList3[1])
			if listPlayer == nil then
				table.remove(self.queueAssistList3, 1)
				goto continue3
			end
			if listPlayer.alive == true then
				RCON:SendCommand('admin.killPlayer', {listPlayer.name})
			end
			if player.alive == true then
				RCON:SendCommand('admin.killPlayer', {player.name})
			end
			listPlayer.teamId = TeamId.Team2
			player.teamId = TeamId.Team3
			table.remove(self.queueAssistList3, 1)
		end
		::continue4::
		if self.queueAssistList4[1] ~= nil then
			listPlayer = PlayerManager:GetPlayerByName(self.queueAssistList4[1])
			if listPlayer == nil then
				table.remove(self.queueAssistList4, 1)
				goto continue4
			end
			if listPlayer.alive == true then
				RCON:SendCommand('admin.killPlayer', {listPlayer.name})
			end
			if player.alive == true then
				RCON:SendCommand('admin.killPlayer', {player.name})
			end
			listPlayer.teamId = TeamId.Team2
			player.teamId = TeamId.Team4
			table.remove(self.queueAssistList4, 1)
		end
	elseif player.teamId == TeamId.Team3 then
		::continue1::
		if self.queueAssistList1[1] ~= nil then
			listPlayer = PlayerManager:GetPlayerByName(self.queueAssistList1[1])
			if listPlayer == nil then
				table.remove(self.queueAssistList1, 1)
				goto continue1
			end
			if listPlayer.alive == true then
				RCON:SendCommand('admin.killPlayer', {listPlayer.name})
			end
			if player.alive == true then
				RCON:SendCommand('admin.killPlayer', {player.name})
			end
			listPlayer.teamId = TeamId.Team3
			player.teamId = TeamId.Team1
			table.remove(self.queueAssistList1, 1)
		end
		::continue2::
		if self.queueAssistList2[1] ~= nil then
			listPlayer = PlayerManager:GetPlayerByName(self.queueAssistList2[1])
			if listPlayer == nil then
				table.remove(self.queueAssistList2, 1)
				goto continue2
			end
			if listPlayer.alive == true then
				RCON:SendCommand('admin.killPlayer', {listPlayer.name})
			end
			if player.alive == true then
				RCON:SendCommand('admin.killPlayer', {player.name})
			end
			listPlayer.teamId = TeamId.Team3
			player.teamId = TeamId.Team2
			table.remove(self.queueAssistList2, 1)
		end
		::continue4::
		if self.queueAssistList4[1] ~= nil then
			listPlayer = PlayerManager:GetPlayerByName(self.queueAssistList4[1])
			if listPlayer == nil then
				table.remove(self.queueAssistList4, 1)
				goto continue4
			end
			if listPlayer.alive == true then
				RCON:SendCommand('admin.killPlayer', {listPlayer.name})
			end
			if player.alive == true then
				RCON:SendCommand('admin.killPlayer', {player.name})
			end
			listPlayer.teamId = TeamId.Team3
			player.teamId = TeamId.Team4
			table.remove(self.queueAssistList4, 1)
		end
	else
		::continue1::
		if self.queueAssistList1[1] ~= nil then
			listPlayer = PlayerManager:GetPlayerByName(self.queueAssistList1[1])
			if listPlayer == nil then
				table.remove(self.queueAssistList1, 1)
				goto continue1
			end
			if listPlayer.alive == true then
				RCON:SendCommand('admin.killPlayer', {listPlayer.name})
			end
			if player.alive == true then
				RCON:SendCommand('admin.killPlayer', {player.name})
			end
			listPlayer.teamId = TeamId.Team4
			player.teamId = TeamId.Team1
			table.remove(self.queueAssistList1, 1)
		end
		::continue2::
		if self.queueAssistList2[1] ~= nil then
			listPlayer = PlayerManager:GetPlayerByName(self.queueAssistList2[1])
			if listPlayer == nil then
				table.remove(self.queueAssistList2, 1)
				goto continue2
			end
			if listPlayer.alive == true then
				RCON:SendCommand('admin.killPlayer', {listPlayer.name})
			end
			if player.alive == true then
				RCON:SendCommand('admin.killPlayer', {player.name})
			end
			listPlayer.teamId = TeamId.Team4
			player.teamId = TeamId.Team2
			table.remove(self.queueAssistList2, 1)
		end
		::continue3::
		if self.queueAssistList3[1] ~= nil then
			listPlayer = PlayerManager:GetPlayerByName(self.queueAssistList3[1])
			if listPlayer == nil then
				table.remove(self.queueAssistList3, 1)
				goto continue3
			end
			if listPlayer.alive == true then
				RCON:SendCommand('admin.killPlayer', {listPlayer.name})
			end
			if player.alive == true then
				RCON:SendCommand('admin.killPlayer', {player.name})
			end
			listPlayer.teamId = TeamId.Team4
			player.teamId = TeamId.Team3
			table.remove(self.queueAssistList3, 1)
		end
	end
	if playerTeamId == player.teamId then
		self:OnQueueAssistEnemyTeam(player)
	else
		local messages = {}
		messages[1] = "Assist Enemy Team."
		messages[2] = "You have been switched because of your assist request."
		NetEvents:SendTo('PopupResponse', player, messages)
		print("ASSIST - MOVE - Player " .. player.name .. " is now helping the enemy team " .. player.teamId .. ".")
		messages = {}
		messages[1] = "Assist Enemy Team."
		messages[2] = "You have been switched because of your assist request."
		NetEvents:SendTo('PopupResponse', listPlayer, messages)	
		print("ASSIST - MOVE - Player " .. listPlayer.name .. " is now helping the enemy team " .. listPlayer.teamId .. ".")
	end
end

function BetterIngameAdmin:OnCancelAssistEnemyTeam(player)
	if player.teamId == 1 then
		for i,listPlayerName in pairs(self.queueAssistList1) do
			if player.name == listPlayerName then
				table.remove(self.queueAssistList1, i)
				local messages = {}
				messages[1] = "Assist Queue Cancelled."
				messages[2] = "We removed you from the assist queue."
				NetEvents:SendTo('PopupResponse', player, messages)
				print("ASSIST - CANCEL - Player " .. player.name .. " cancelled the assist and was removed from the assist queue.")
				return
			end
		end
		for i,listPlayerName in pairs(self.queueAssistList2) do
			if player.name == listPlayerName then
				table.remove(self.queueAssistList2, i)
				local messages = {}
				messages[1] = "Assist Queue Cancelled."
				messages[2] = "We removed you from the assist queue."
				NetEvents:SendTo('PopupResponse', player, messages)
				print("ASSIST - CANCEL - Player " .. player.name .. " cancelled the assist and was removed from the assist queue.")
				return
			end
		end
		for i,listPlayerName in pairs(self.queueAssistList3) do
			if player.name == listPlayerName then
				table.remove(self.queueAssistList3, i)
				local messages = {}
				messages[1] = "Assist Queue Cancelled."
				messages[2] = "We removed you from the assist queue."
				NetEvents:SendTo('PopupResponse', player, messages)
				print("ASSIST - CANCEL - Player " .. player.name .. " cancelled the assist and was removed from the assist queue.")
				return
			end
		end
		for i,listPlayerName in pairs(self.queueAssistList4) do
			if player.name == listPlayerName then
				table.remove(self.queueAssistList4, i)
				local messages = {}
				messages[1] = "Assist Queue Cancelled."
				messages[2] = "We removed you from the assist queue."
				NetEvents:SendTo('PopupResponse', player, messages)
				print("ASSIST - CANCEL - Player " .. player.name .. " cancelled the assist and was removed from the assist queue.")
				return
			end
		end
		-- Error you are in no queue
	elseif player.teamId == 2 then
		for i,listPlayerName in pairs(self.queueAssistList2) do
			if player.name == listPlayerName then
				table.remove(self.queueAssistList2, i)
				local messages = {}
				messages[1] = "Assist Queue Cancelled."
				messages[2] = "We removed you from the assist queue."
				NetEvents:SendTo('PopupResponse', player, messages)
				print("ASSIST - CANCEL - Player " .. player.name .. " cancelled the assist and was removed from the assist queue.")
				return
			end
		end
		for i,listPlayerName in pairs(self.queueAssistList1) do
			if player.name == listPlayerName then
				table.remove(self.queueAssistList1, i)
				local messages = {}
				messages[1] = "Assist Queue Cancelled."
				messages[2] = "We removed you from the assist queue."
				NetEvents:SendTo('PopupResponse', player, messages)
				print("ASSIST - CANCEL - Player " .. player.name .. " cancelled the assist and was removed from the assist queue.")
				return
			end
		end
		for i,listPlayerName in pairs(self.queueAssistList3) do
			if player.name == listPlayerName then
				table.remove(self.queueAssistList3, i)
				local messages = {}
				messages[1] = "Assist Queue Cancelled."
				messages[2] = "We removed you from the assist queue."
				NetEvents:SendTo('PopupResponse', player, messages)
				print("ASSIST - CANCEL - Player " .. player.name .. " cancelled the assist and was removed from the assist queue.")
				return
			end
		end
		for i,listPlayerName in pairs(self.queueAssistList4) do
			if player.name == listPlayerName then
				table.remove(self.queueAssistList4, i)
				local messages = {}
				messages[1] = "Assist Queue Cancelled."
				messages[2] = "We removed you from the assist queue."
				NetEvents:SendTo('PopupResponse', player, messages)
				print("ASSIST - CANCEL - Player " .. player.name .. " cancelled the assist and was removed from the assist queue.")
				return
			end
		end
		-- Error you are in no queue
	elseif player.teamId == 3 then
		for i,listPlayerName in pairs(self.queueAssistList3) do
			if player.name == listPlayerName then
				table.remove(self.queueAssistList3, i)
				local messages = {}
				messages[1] = "Assist Queue Cancelled."
				messages[2] = "We removed you from the assist queue."
				NetEvents:SendTo('PopupResponse', player, messages)
				print("ASSIST - CANCEL - Player " .. player.name .. " cancelled the assist and was removed from the assist queue.")
				return
			end
		end
		for i,listPlayerName in pairs(self.queueAssistList1) do
			if player.name == listPlayerName then
				table.remove(self.queueAssistList1, i)
				local messages = {}
				messages[1] = "Assist Queue Cancelled."
				messages[2] = "We removed you from the assist queue."
				NetEvents:SendTo('PopupResponse', player, messages)
				print("ASSIST - CANCEL - Player " .. player.name .. " cancelled the assist and was removed from the assist queue.")
				return
			end
		end
		for i,listPlayerName in pairs(self.queueAssistList2) do
			if player.name == listPlayerName then
				table.remove(self.queueAssistList2, i)
				local messages = {}
				messages[1] = "Assist Queue Cancelled."
				messages[2] = "We removed you from the assist queue."
				NetEvents:SendTo('PopupResponse', player, messages)
				print("ASSIST - CANCEL - Player " .. player.name .. " cancelled the assist and was removed from the assist queue.")
				return
			end
		end
		for i,listPlayerName in pairs(self.queueAssistList4) do
			if player.name == listPlayerName then
				table.remove(self.queueAssistList4, i)
				local messages = {}
				messages[1] = "Assist Queue Cancelled."
				messages[2] = "We removed you from the assist queue."
				NetEvents:SendTo('PopupResponse', player, messages)
				print("ASSIST - CANCEL - Player " .. player.name .. " cancelled the assist and was removed from the assist queue.")
				return
			end
		end
		-- Error you are in no queue
	elseif player.teamId == 4 then
		for i,listPlayerName in pairs(self.queueAssistList4) do
			if player.name == listPlayerName then
				table.remove(self.queueAssistList4, i)
				local messages = {}
				messages[1] = "Assist Queue Cancelled."
				messages[2] = "We removed you from the assist queue."
				NetEvents:SendTo('PopupResponse', player, messages)
				print("ASSIST - CANCEL - Player " .. player.name .. " cancelled the assist and was removed from the assist queue.")
				return
			end
		end
		for i,listPlayerName in pairs(self.queueAssistList1) do
			if player.name == listPlayerName then
				table.remove(self.queueAssistList1, i)
				local messages = {}
				messages[1] = "Assist Queue Cancelled."
				messages[2] = "We removed you from the assist queue."
				NetEvents:SendTo('PopupResponse', player, messages)
				print("ASSIST - CANCEL - Player " .. player.name .. " cancelled the assist and was removed from the assist queue.")
				return
			end
		end
		for i,listPlayerName in pairs(self.queueAssistList2) do
			if player.name == listPlayerName then
				table.remove(self.queueAssistList2, i)
				local messages = {}
				messages[1] = "Assist Queue Cancelled."
				messages[2] = "We removed you from the assist queue."
				NetEvents:SendTo('PopupResponse', player, messages)
				print("ASSIST - CANCEL - Player " .. player.name .. " cancelled the assist and was removed from the assist queue.")
				return
			end
		end
		for i,listPlayerName in pairs(self.queueAssistList3) do
			if player.name == listPlayerName then
				table.remove(self.queueAssistList3, i)
				local messages = {}
				messages[1] = "Assist Queue Cancelled."
				messages[2] = "We removed you from the assist queue."
				NetEvents:SendTo('PopupResponse', player, messages)
				print("ASSIST - CANCEL - Player " .. player.name .. " cancelled the assist and was removed from the assist queue.")
				return
			end
		end
		-- Error you are in no queue
		print("ASSIST - CANCEL Error - Player " .. player.name .. " was in no assist queue.")
	end
end
-- Endregion

-- Region Squad stuff
function BetterIngameAdmin:OnLeaveSquad(player)
	player.squadId = SquadId.SquadNone
	local messages = {}
	messages[1] = "Left Squad."
	messages[2] = "You left the squad."
	NetEvents:SendTo('PopupResponse', player, messages)
end

function BetterIngameAdmin:OnCreateSquad(player)
	for i=1,32 do
		if TeamSquadManager:GetSquadPlayerCount(player.teamId, i) == 0 then
			player.squadId = i
			RCON:SendCommand('squad.private', {tostring(player.teamId), tostring(player.squadId), "false"})
			local messages = {}
			messages[1] = "Create Squad."
			messages[2] = "You created a squad with the ID: ".. player.squadId .."."
			NetEvents:SendTo('PopupResponse', player, messages)
			return
		end
	end
end

function BetterIngameAdmin:OnJoinSquad(player, playerName)
	local messages = {}
	local targetPlayer = PlayerManager:GetPlayerByName(playerName)
	if targetPlayer ~= nil then
		if player.teamId == targetPlayer.teamId and targetPlayer.isSquadPrivate == false and tonumber(self.serverConfig[43]) > TeamSquadManager:GetSquadPlayerCount(targetPlayer.teamId, targetPlayer.squadId) then
			player.squadId = targetPlayer.squadId
			messages = {}
			messages[1] = "Squad Joined."
			messages[2] = "You joined the squad with the ID: ".. player.squadId .."."
			NetEvents:SendTo('PopupResponse', player, messages)
		else
			messages = {}
			messages[1] = "Error."
			messages[2] = "You couldn't join the squad with the ID: ".. player.squadId ..". Maybe the squad is full or private."
			NetEvents:SendTo('PopupResponse', player, messages)
		end
	end
end

function BetterIngameAdmin:OnPrivateSquad(player)
	local messages = {}
	if player.isSquadPrivate == false and player.isSquadLeader == true then
		RCON:SendCommand('squad.private', {tostring(player.teamId), tostring(player.squadId), "true"})
		messages = {}
		messages[1] = "Squad private."
		messages[2] = "Your squad with the ID: ".. player.squadId .." is now private."
		NetEvents:SendTo('PopupResponse', player, messages)
	else
		RCON:SendCommand('squad.private', {tostring(player.teamId), tostring(player.squadId), "false"})
		messages = {}
		messages[1] = "Squad not private."
		messages[2] = "Your squad with the ID: ".. player.squadId .." is now NOT private."
		NetEvents:SendTo('PopupResponse', player, messages)
	end
end

function BetterIngameAdmin:OnKickFromSquad(player, playerName)
	local targetPlayer = PlayerManager:GetPlayerByName(playerName)
	if targetPlayer ~= nil and player.isSquadLeader == true then
		targetPlayer.squadId = SquadId.SquadNone
		local messages = {}
		messages[1] = "Player kicked from Squad."
		messages[2] = "You kicked the player ".. targetPlayer.name .." from your squad."
		NetEvents:SendTo('PopupResponse', player, messages)
	end
end

function BetterIngameAdmin:OnMakeSquadLeader(player, playerName)
	local targetPlayer = PlayerManager:GetPlayerByName(playerName)
	if targetPlayer ~= nil and player.isSquadLeader == true then
		RCON:SendCommand('squad.leader', {tostring(targetPlayer.teamId), tostring(targetPlayer.squadId), playerName})
		local messages = {}
		messages[1] = "Player is now Squad Leader."
		messages[2] = "You promoted the player ".. targetPlayer.name .." to your squad leader and demoted yourself to a normal squad member."
		NetEvents:SendTo('PopupResponse', player, messages)
	end
end
-- Endregion

-- Region Admin Map Rotation
function BetterIngameAdmin:OnGetMapRotation()
	local args = {}
	local arg = RCON:SendCommand('mapList.list')
	if arg ~= nil and arg[2] ~= nil then
		table.remove(arg, 1)
		table.insert(args, arg)
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('mapList.getMapIndices')
	if arg ~= nil and arg[2] ~= nil then
		table.remove(arg, 1)
		table.insert(args, arg)
	else
		table.insert(args, " ")
	end
	
	NetEvents:Broadcast('MapRotation', args)
end

function BetterIngameAdmin:OnSetNextMap(player, mapIndex)
	if (self.adminList[player.name] == nil or self.adminList[player.name].canUseMapFunctions == nil) and self.owner ~= player.name then
		-- That guy is no admin or doesn't have that ability. That guy is also not the server owner.
		print("ADMIN - SET NEXT MAP - Error - Player " .. player.name .. " is no admin.")
		return
	end
	mapIndex = tonumber(mapIndex) - 1
	RCON:SendCommand('mapList.setNextMapIndex', {tostring(mapIndex)})
	print("ADMIN - SET NEXT MAP - Admin " .. player.name .. " has changed the next map index to " .. tostring(mapIndex) .. ".")
	self:OnGetMapRotation()
end

function BetterIngameAdmin:OnRunNextRound(player)
	if (self.adminList[player.name] == nil or self.adminList[player.name].canUseMapFunctions == nil) and self.owner ~= player.name then
		-- That guy is no admin or doesn't have that ability. That guy is also not the server owner.
		print("ADMIN - RUN NEXT ROUND - Error - Player " .. player.name .. " is no admin.")
		return
	end
	RCON:SendCommand('mapList.runNextRound')
	print("ADMIN - RUN NEXT ROUND - Player " .. player.name .. " ran the next round.")
end

function BetterIngameAdmin:OnRestartRound(player)
	if (self.adminList[player.name] == nil or self.adminList[player.name].canUseMapFunctions == nil ) and self.owner ~= player.name then
		-- That guy is no admin or doesn't have that ability. That guy is also not the server owner.
		print("ADMIN - RESTART ROUND - Error - Player " .. player.name .. " is no admin.")
		return
	end
	RCON:SendCommand('mapList.restartRound')
	print("ADMIN - RESTART ROUND - Player " .. player.name .. " restarted the round.")
end
-- Endregion

-- Region Admin Server Setup
function BetterIngameAdmin:OnGetServerSetupSettings(player)
	local args = {}
	local arg = RCON:SendCommand('vars.serverName')
	if arg ~= nil and arg[2] ~= nil then
		table.remove(arg, 1)
		table.insert(args, arg)
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.serverDescription')
	if arg ~= nil and arg[2] ~= nil then
		table.remove(arg, 1)
		table.insert(args, arg)
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.serverMessage')
	if arg ~= nil and arg[2] ~= nil then
		table.remove(arg, 1)
		table.insert(args, arg)
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.gamePassword')
	if arg ~= nil and arg[2] ~= nil then
		table.remove(arg, 1)
		table.insert(args, arg)
	else
		table.insert(args, " ")
	end
	-- ToDo: Add preset, maprotation and overwritePresetOnStart
	NetEvents:SendTo('ServerSetupSettings', player, args)
end

function BetterIngameAdmin:OnSaveServerSetupSettings(player, args)
	if (self.adminList[player.name] == nil or self.adminList[player.name].canAlterServerSettings == nil) and self.owner ~= player.name then
		-- That guy is no admin or doesn't have that ability. That guy is also not the server owner.
		print("ADMIN - SAVE SERVER SETUP SETTINGS - Error - Player " .. player.name .. " is no admin.")
		return
	end
	RCON:SendCommand('vars.serverName', {args[1]})
	self.serverConfig[1] = args[1]
	RCON:SendCommand('vars.serverDescription', {args[2]})
	self.serverConfig[2] = args[2]
	RCON:SendCommand('vars.serverMessage', {args[3]})
	self.serverConfig[3] = args[3]
	RCON:SendCommand('vars.gamePassword', {args[4]})
	self.serverConfig[4] = args[4]
	print("ADMIN - SAVE SERVER SETUP SETTINGS - Player " .. player.name .. " updated the server name: " .. args[1] .. ", server description: " .. args[2] .. ", server message: " .. args[3] .. ", and game password: " .. args[4] .. ".")
end
-- Endregion

-- Region Manage Presets
function BetterIngameAdmin:OnManagePresets(player, args)
	if (self.adminList[player.name] == nil or self.adminList[player.name].canAlterServerSettings == nil) and self.owner ~= player.name then
		-- That guy is no admin or doesn't have that ability. That guy is also not the server owner.
		print("ADMIN - MANAGE PRESETS - Error - Player " .. player.name .. " is no admin.")
		return
	end
	if args[1] == "normal" then
		self:PresetNormal()
		print("ADMIN - MANAGE PRESETS - Player " .. player.name .. " changed the presets to: NORMAL.")
	elseif args[1] == "hardcore" then
		self:PresetHardcore()
		print("ADMIN - MANAGE PRESETS - Player " .. player.name .. " changed the presets to: HARDCORE.")
	elseif args[1] == "infantry" then
		self:PresetInfantry()
		print("ADMIN - MANAGE PRESETS - Player " .. player.name .. " changed the presets to: INFANTRY.")
	elseif args[1] == "hardcoreNoMap" then
		self:PresetHardcoreNoMap()
		print("ADMIN - MANAGE PRESETS - Player " .. player.name .. " changed the presets to: HARDCORE NO MAP.")
	elseif args[1] == "custom" then
		self:PresetCustom(args)
		print("ADMIN - MANAGE PRESETS - Player " .. player.name .. " changed the presets to: CUSTOM.")
	end
	NetEvents:Broadcast('ServerInfo', self.serverConfig)
	local messages = {}
	messages[1] = "Changed server settings."
	messages[2] = "You successfully changed the server settings."
	NetEvents:SendTo('PopupResponse', player, messages)
end
function BetterIngameAdmin:PresetNormal()
	RCON:SendCommand('vars.friendlyFire', {"false"})
	self.serverConfig[6] = "false"
	RCON:SendCommand('vars.idleTimeout', {"300"})
	self.serverConfig[29] = "300"
	RCON:SendCommand('vars.autoBalance', {"true"})
	self.serverConfig[5] = "true"
	RCON:SendCommand('vars.teamKillCountForKick', {"5"})
	self.serverConfig[24] = "5"
	RCON:SendCommand('vars.teamKillKickForBan', {"3"})
	self.serverConfig[28] = "3"
	RCON:SendCommand('vars.vehicleSpawnAllowed', {"true"})
	self.serverConfig[15] = "true"
	RCON:SendCommand('vars.regenerateHealth', {"true"})
	self.serverConfig[14] = "true"
	RCON:SendCommand('vars.onlySquadLeaderSpawn', {"false"})
	self.serverConfig[16] = "false"
	RCON:SendCommand('vars.minimap', {"true"})
	self.serverConfig[8] = "true"
	RCON:SendCommand('vars.hud', {"true"})
	self.serverConfig[9] = "true"
	RCON:SendCommand('vars.miniMapSpotting', {"true"})
	self.serverConfig[11] = "true"
	RCON:SendCommand('vars.3dSpotting', {"true"})
	self.serverConfig[10] = "true"
	RCON:SendCommand('vars.killCam', {"true"})
	self.serverConfig[7] = "true"
	RCON:SendCommand('vars.3pCam', {"true"})
	self.serverConfig[13] = "true"
	RCON:SendCommand('vars.nameTag', {"true"})
	self.serverConfig[12] = "true"
	RCON:SendCommand('vars.gunMasterWeaponsPreset', {"0"})
	self.serverConfig[40] = "0"
	RCON:SendCommand('vars.ctfRoundTimeModifier', {"100"})
	self.serverConfig[49] = "100"
	RCON:SendCommand('vars.playerRespawnTime', {"100"})
	self.serverConfig[36] = "100"
	RCON:SendCommand('vars.playerManDownTime', {"100"})
	self.serverConfig[37] = "100"
	RCON:SendCommand('vars.soldierHealth', {"100"})
	self.serverConfig[35] = "100"
	RCON:SendCommand('vars.bulletDamage', {"100"})
	self.serverConfig[38] = "100"
	RCON:SendCommand('vu.ColorCorrectionEnabled', {"true"})
	self.serverConfig[22] = "true"
	RCON:SendCommand('vu.SunFlareEnabled', {"true"})
	self.serverConfig[21] = "true"
	RCON:SendCommand('vu.SuppressionMultiplier', {"100"})
	self.serverConfig[41] = "100"
	RCON:SendCommand('vu.TimeScale', {"1.0"})
	self.serverConfig[42] = "1.0"
	RCON:SendCommand('vu.DesertingAllowed', {"false"})
	self.serverConfig[18] = "false"
	RCON:SendCommand('vu.DestructionEnabled', {"true"})
	self.serverConfig[17] = "true"
	RCON:SendCommand('vu.VehicleDisablingEnabled', {"true"})
	self.serverConfig[19] = "true"
	RCON:SendCommand('vu.SquadSize', {"4"})
	self.serverConfig[43] = "4"
end
function BetterIngameAdmin:PresetHardcore()
	RCON:SendCommand('vars.friendlyFire', {"true"})
	self.serverConfig[6] = "true"
	RCON:SendCommand('vars.idleTimeout', {"300"})
	self.serverConfig[29] = "300"
	RCON:SendCommand('vars.autoBalance', {"true"})
	self.serverConfig[5] = "true"
	RCON:SendCommand('vars.teamKillCountForKick', {"5"})
	self.serverConfig[24] = "5"
	RCON:SendCommand('vars.teamKillKickForBan', {"3"})
	self.serverConfig[28] = "3"
	RCON:SendCommand('vars.vehicleSpawnAllowed', {"true"})
	self.serverConfig[15] = "true" 
	RCON:SendCommand('vars.regenerateHealth', {"false"})
	self.serverConfig[14] = "false"
	RCON:SendCommand('vars.onlySquadLeaderSpawn', {"true"})
	self.serverConfig[16] = "true"
	RCON:SendCommand('vars.minimap', {"true"})
	self.serverConfig[8] = "true"
	RCON:SendCommand('vars.hud', {"false"})
	self.serverConfig[9] = "false"
	RCON:SendCommand('vars.miniMapSpotting', {"true"})
	self.serverConfig[11] = "true"
	RCON:SendCommand('vars.3dSpotting', {"false"})
	self.serverConfig[10] = "false"
	RCON:SendCommand('vars.killCam', {"false"})
	self.serverConfig[7] = "false"
	RCON:SendCommand('vars.3pCam', {"false"})
	self.serverConfig[13] = "false"
	RCON:SendCommand('vars.nameTag', {"false"})
	self.serverConfig[12] = "false"
	RCON:SendCommand('vars.gunMasterWeaponsPreset', {"0"})
	self.serverConfig[40] = "0"
	RCON:SendCommand('vars.ctfRoundTimeModifier', {"100"})
	self.serverConfig[49] = "100"
	RCON:SendCommand('vars.playerRespawnTime', {"100"})
	self.serverConfig[36] = "100"
	RCON:SendCommand('vars.playerManDownTime', {"100"})
	self.serverConfig[37] = "100"
	RCON:SendCommand('vars.soldierHealth', {"60"})
	self.serverConfig[35] = "60"
	RCON:SendCommand('vars.bulletDamage', {"100"})
	self.serverConfig[38] = "100"
	RCON:SendCommand('vu.ColorCorrectionEnabled', {"true"})
	self.serverConfig[22] = "true"
	RCON:SendCommand('vu.SunFlareEnabled', {"true"})
	self.serverConfig[21] = "true"
	RCON:SendCommand('vu.SuppressionMultiplier', {"100"})
	self.serverConfig[41] = "100"
	RCON:SendCommand('vu.TimeScale', {"1.0"})
	self.serverConfig[42] = "1.0"
	RCON:SendCommand('vu.DesertingAllowed', {"false"})
	self.serverConfig[18] = "false"
	RCON:SendCommand('vu.DestructionEnabled', {"true"})
	self.serverConfig[17] = "true"
	RCON:SendCommand('vu.VehicleDisablingEnabled', {"true"})
	self.serverConfig[19] = "true"
	RCON:SendCommand('vu.SquadSize', {"4"})
	self.serverConfig[43] = "4"
end
function BetterIngameAdmin:PresetInfantry()
	RCON:SendCommand('vars.friendlyFire', {"false"})
	self.serverConfig[6] = "false"
	RCON:SendCommand('vars.idleTimeout', {"300"})
	self.serverConfig[29] = "300"
	RCON:SendCommand('vars.autoBalance', {"true"})
	self.serverConfig[5] = "true"
	RCON:SendCommand('vars.teamKillCountForKick', {"5"})
	self.serverConfig[24] = "5"
	RCON:SendCommand('vars.teamKillKickForBan', {"3"})
	self.serverConfig[28] = "3"
	RCON:SendCommand('vars.vehicleSpawnAllowed', {"false"})
	self.serverConfig[15] ="false"
	RCON:SendCommand('vars.regenerateHealth', {"true"})
	self.serverConfig[14] = "true"
	RCON:SendCommand('vars.onlySquadLeaderSpawn', {"false"})
	self.serverConfig[16] = "false"
	RCON:SendCommand('vars.minimap', {"true"})
	self.serverConfig[8] = "true"
	RCON:SendCommand('vars.hud', {"true"})
	self.serverConfig[9] = "true"
	RCON:SendCommand('vars.miniMapSpotting', {"true"})
	self.serverConfig[11] = "true"
	RCON:SendCommand('vars.3dSpotting', {"true"})
	self.serverConfig[10] = "true"
	RCON:SendCommand('vars.killCam', {"true"})
	self.serverConfig[7] = "true"
	RCON:SendCommand('vars.3pCam', {"false"})
	self.serverConfig[13] = "false"
	RCON:SendCommand('vars.nameTag', {"true"})
	self.serverConfig[12] = "true"
	RCON:SendCommand('vars.gunMasterWeaponsPreset', {"0"})
	self.serverConfig[40] = "0"
	RCON:SendCommand('vars.ctfRoundTimeModifier', {"100"})
	self.serverConfig[49] = "100"
	RCON:SendCommand('vars.playerRespawnTime', {"100"})
	self.serverConfig[36] = "100"
	RCON:SendCommand('vars.playerManDownTime', {"100"})
	self.serverConfig[37] = "100"
	RCON:SendCommand('vars.soldierHealth', {"100"})
	self.serverConfig[35] = "100"
	RCON:SendCommand('vars.bulletDamage', {"100"})
	self.serverConfig[38] = "100"
	RCON:SendCommand('vu.ColorCorrectionEnabled', {"true"})
	self.serverConfig[22] = "true"
	RCON:SendCommand('vu.SunFlareEnabled', {"true"})
	self.serverConfig[21] = "true"
	RCON:SendCommand('vu.SuppressionMultiplier', {"100"})
	self.serverConfig[41] = "100"
	RCON:SendCommand('vu.TimeScale', {"1.0"})
	self.serverConfig[42] = "1.0"
	RCON:SendCommand('vu.DesertingAllowed', {"false"})
	self.serverConfig[18] = "false"
	RCON:SendCommand('vu.DestructionEnabled', {"true"})
	self.serverConfig[17] = "true"
	RCON:SendCommand('vu.VehicleDisablingEnabled', {"true"})
	self.serverConfig[19] = "true"
	RCON:SendCommand('vu.SquadSize', {"4"})
	self.serverConfig[43] = "4"
end
function BetterIngameAdmin:PresetHardcoreNoMap()
	RCON:SendCommand('vars.friendlyFire', {"true"})
	self.serverConfig[6] = "true"
	RCON:SendCommand('vars.idleTimeout', {"300"})
	self.serverConfig[29] = "300"
	RCON:SendCommand('vars.autoBalance', {"true"})
	self.serverConfig[5] = "true"
	RCON:SendCommand('vars.teamKillCountForKick', {"5"})
	self.serverConfig[24] = "5"
	RCON:SendCommand('vars.teamKillKickForBan', {"3"})
	self.serverConfig[28] = "3"
	RCON:SendCommand('vars.vehicleSpawnAllowed', {"true"})
	self.serverConfig[15] = "true"
	RCON:SendCommand('vars.regenerateHealth', {"false"})
	self.serverConfig[14] = "false"
	RCON:SendCommand('vars.onlySquadLeaderSpawn', {"true"})
	self.serverConfig[16] = "true"
	RCON:SendCommand('vars.minimap', {"false"})
	self.serverConfig[8] = "false"
	RCON:SendCommand('vars.hud', {"false"})
	self.serverConfig[9] = "false"
	RCON:SendCommand('vars.miniMapSpotting', {"true"})
	self.serverConfig[11] = "true"
	RCON:SendCommand('vars.3dSpotting', {"false"})
	self.serverConfig[10] = "false"
	RCON:SendCommand('vars.killCam', {"false"})
	self.serverConfig[7] = "false"
	RCON:SendCommand('vars.3pCam', {"false"})
	self.serverConfig[13] = "false"
	RCON:SendCommand('vars.nameTag', {"false"})
	self.serverConfig[12] = "false"
	RCON:SendCommand('vars.gunMasterWeaponsPreset', {"0"})
	self.serverConfig[40] = "0"
	RCON:SendCommand('vars.ctfRoundTimeModifier', {"100"})
	self.serverConfig[49] = "100"
	RCON:SendCommand('vars.playerRespawnTime', {"100"})
	self.serverConfig[36] = "100"
	RCON:SendCommand('vars.playerManDownTime', {"100"})
	self.serverConfig[37] = "100"
	RCON:SendCommand('vars.soldierHealth', {"60"})
	self.serverConfig[35] = "60"
	RCON:SendCommand('vars.bulletDamage', {"100"})
	self.serverConfig[38] = "100"
	RCON:SendCommand('vu.ColorCorrectionEnabled', {"true"})
	self.serverConfig[22] = "true"
	RCON:SendCommand('vu.SunFlareEnabled', {"true"})
	self.serverConfig[21] = "true"
	RCON:SendCommand('vu.SuppressionMultiplier', {"100"})
	self.serverConfig[41] = "100"
	RCON:SendCommand('vu.TimeScale', {"1.0"})
	self.serverConfig[42] = "1.0"
	RCON:SendCommand('vu.DesertingAllowed', {"false"})
	self.serverConfig[18] = "false"
	RCON:SendCommand('vu.DestructionEnabled', {"true"})
	self.serverConfig[17] = "true"
	RCON:SendCommand('vu.VehicleDisablingEnabled', {"true"})
	self.serverConfig[19] = "true"
	RCON:SendCommand('vu.SquadSize', {"4"})
	self.serverConfig[43] = "4"
end
function BetterIngameAdmin:PresetCustom(args)
	RCON:SendCommand('vars.friendlyFire', {args[2]})
	self.serverConfig[6] = args[2]
	RCON:SendCommand('vars.idleTimeout', {args[3]})
	self.serverConfig[29] = args[3]
	RCON:SendCommand('vars.autoBalance', {args[4]})
	self.serverConfig[5] = args[4]
	RCON:SendCommand('vars.teamKillCountForKick', {args[5]})
	self.serverConfig[24] = args[5]
	RCON:SendCommand('vars.teamKillKickForBan', {args[6]})
	self.serverConfig[28] = args[6]
	RCON:SendCommand('vars.vehicleSpawnAllowed', {args[7]})
	self.serverConfig[15] = args[7]
	RCON:SendCommand('vars.regenerateHealth', {args[8]})
	self.serverConfig[14] = args[8]
	RCON:SendCommand('vars.onlySquadLeaderSpawn', {args[9]})
	self.serverConfig[16] = args[9]
	RCON:SendCommand('vars.minimap', {args[10]})
	self.serverConfig[8] = args[10]
	RCON:SendCommand('vars.hud', {args[11]})
	self.serverConfig[9] = args[11]
	RCON:SendCommand('vars.miniMapSpotting', {args[12]})
	self.serverConfig[11] = args[12]
	RCON:SendCommand('vars.3dSpotting', {args[13]})
	self.serverConfig[10] = args[13]
	RCON:SendCommand('vars.killCam', {args[14]})
	self.serverConfig[7] = args[14]
	RCON:SendCommand('vars.3pCam', {args[15]})
	self.serverConfig[13] = args[15]
	RCON:SendCommand('vars.nameTag', {args[16]})
	self.serverConfig[12] = args[16]
	RCON:SendCommand('vars.gunMasterWeaponsPreset', {args[17]})
	self.serverConfig[40] = args[17]
	RCON:SendCommand('vars.ctfRoundTimeModifier', {args[18]})
	self.serverConfig[49] = args[18]
	RCON:SendCommand('vars.playerRespawnTime', {args[19]})
	self.serverConfig[36] = args[19]
	RCON:SendCommand('vars.playerManDownTime', {args[20]})
	self.serverConfig[37] = args[20]
	RCON:SendCommand('vars.soldierHealth', {args[21]})
	self.serverConfig[35] = args[21]
	RCON:SendCommand('vars.bulletDamage', {args[22]})
	self.serverConfig[38] = args[22]
	RCON:SendCommand('vu.ColorCorrectionEnabled', {args[23]})
	self.serverConfig[22] = args[23]
	RCON:SendCommand('vu.SunFlareEnabled', {args[24]})
	self.serverConfig[21] = args[24]
	RCON:SendCommand('vu.SuppressionMultiplier', {args[25]})
	self.serverConfig[41] = args[25]
	RCON:SendCommand('vu.TimeScale', {args[26]})
	self.serverConfig[42] = args[26]
	RCON:SendCommand('vu.DesertingAllowed', {args[27]})
	self.serverConfig[18] = args[27]
	RCON:SendCommand('vu.DestructionEnabled', {args[28]})
	self.serverConfig[17] = args[28]
	RCON:SendCommand('vu.VehicleDisablingEnabled', {args[29]})
	self.serverConfig[19] = args[29]
	RCON:SendCommand('vu.SquadSize', {args[30]})
	self.serverConfig[43] = args[30]
end
-- Endregion

-- Region Manage ModSettings
function BetterIngameAdmin:OnResetModSettings(player)
	if (self.adminList[player.name] == nil or self.adminList[player.name].canAlterServerSettings == nil) and self.owner ~= player.name then
		-- That guy is no admin or doesn't have that ability. That guy is also not the server owner.
		print("MODSETTINGS - Reset - Error - Player " .. player.name .. " is no admin.")
		return
	end
	self.showEnemyCorpses = true
	self.voteDuration = 30
	self.cooldownBetweenVotes = 0
	self.maxVotingStartsPerPlayer = 3
	self.votingParticipationNeeded = 50
	self.enableAssistFunction = true
	
	NetEvents:Broadcast('RefreshModSettings', {self.showEnemyCorpses, self.voteDuration, self.cooldownBetweenVotes, self.maxVotingStartsPerPlayer, self.votingParticipationNeeded, self.enableAssistFunction})
	print("MODSETTINGS - Reset - Admin " .. player.name .. " has updated the mod settings.")
	
	local message = {}
	message[1] = "Mod Settings reset."
	message[2] = "The mod settings have been resetted."
	NetEvents:SendTo('PopupResponse', player, message)
end

function BetterIngameAdmin:OnResetAndSaveModSettings(player)
	if (self.adminList[player.name] == nil or self.adminList[player.name].canAlterServerSettings == nil) and self.owner ~= player.name then
		-- That guy is no admin or doesn't have that ability. That guy is also not the server owner.
		print("MODSETTINGS - Reset & Save - Error - Player " .. player.name .. " is no admin.")
		return
	end
	self.showEnemyCorpses = true
	self.voteDuration = 30
	self.cooldownBetweenVotes = 0
	self.maxVotingStartsPerPlayer = 3
	self.votingParticipationNeeded = 50
	self.enableAssistFunction = true
	
	NetEvents:Broadcast('RefreshModSettings', {self.showEnemyCorpses, self.voteDuration, self.cooldownBetweenVotes, self.maxVotingStartsPerPlayer, self.votingParticipationNeeded, self.enableAssistFunction})
	print("MODSETTINGS - Reset & Save - Admin " .. player.name .. " has updated the mod settings.")
	
	self:SQLSaveModSettings()
	
	local message = {}
	message[1] = "Mod Settings resetted & saved."
	message[2] = "The mod settings have been resetted and saved."
	NetEvents:SendTo('PopupResponse', player, message)
end

function BetterIngameAdmin:OnApplyModSettings(player, args)
	if (self.adminList[player.name] == nil or self.adminList[player.name].canAlterServerSettings == nil) and self.owner ~= player.name then
		-- That guy is no admin or doesn't have that ability. That guy is also not the server owner.
		print("MODSETTINGS - Apply - Error - Player " .. player.name .. " is no admin.")
		return
	end
	self.showEnemyCorpses = args[1]
	self.voteDuration = tonumber(args[2])
	self.cooldownBetweenVotes = tonumber(args[3])
	self.maxVotingStartsPerPlayer = tonumber(args[4])
	self.votingParticipationNeeded = tonumber(args[5])
	self.enableAssistFunction = args[6]
	
	NetEvents:Broadcast('RefreshModSettings', {self.showEnemyCorpses, self.voteDuration, self.cooldownBetweenVotes, self.maxVotingStartsPerPlayer, self.votingParticipationNeeded, self.enableAssistFunction})
	print("MODSETTINGS - Apply - Admin " .. player.name .. " has updated the mod settings.")
	
	local message = {}
	message[1] = "Mod Settings applied."
	message[2] = "The mod settings have been applied."
	NetEvents:SendTo('PopupResponse', player, message)
end

function BetterIngameAdmin:OnSaveModSettings(player, args)
	if (self.adminList[player.name] == nil or self.adminList[player.name].canAlterServerSettings == nil) and self.owner ~= player.name then
		-- That guy is no admin or doesn't have that ability. That guy is also not the server owner.
		print("MODSETTINGS - Save - Error - Player " .. player.name .. " is no admin.")
		return
	end
	self.showEnemyCorpses = args[1]
	self.voteDuration = tonumber(args[2])
	self.cooldownBetweenVotes = tonumber(args[3])
	self.maxVotingStartsPerPlayer = tonumber(args[4])
	self.votingParticipationNeeded = tonumber(args[5])
	self.enableAssistFunction = args[6]
	
	NetEvents:Broadcast('RefreshModSettings', {self.showEnemyCorpses, self.voteDuration, self.cooldownBetweenVotes, self.maxVotingStartsPerPlayer, self.votingParticipationNeeded, self.enableAssistFunction})
	print("MODSETTINGS - Save - Admin " .. player.name .. " has updated the mod settings.")
	
	self:SQLSaveModSettings()
	
	local message = {}
	message[1] = "Mod Settings applied & saved."
	message[2] = "The mod settings have been applied and saved."
	NetEvents:SendTo('PopupResponse', player, message)
end

function BetterIngameAdmin:SQLSaveModSettings()
	
	if not SQL:Open() then
		return
	end
	local query = [[DROP TABLE IF EXISTS mod_settings]]
	if not SQL:Query(query) then
		print('Failed to execute query: ' .. SQL:Error())
		return
	end
	query = [[
	  CREATE TABLE IF NOT EXISTS mod_settings (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		showEnemyCorpses BOOLEAN,
		voteDuration INTEGER,
		cooldownBetweenVotes INTEGER,
		maxVotingStartsPerPlayer INTEGER,
		votingParticipationNeeded INTEGER,
		enableAssistFunction BOOLEAN
	  )
	]]
	if not SQL:Query(query) then
	  print('Failed to execute query: ' .. SQL:Error())
	  return
	end
	query = 'INSERT INTO mod_settings (showEnemyCorpses, voteDuration, cooldownBetweenVotes, maxVotingStartsPerPlayer, votingParticipationNeeded, enableAssistFunction) VALUES (?, ?, ?, ?, ?, ?)'
	if not SQL:Query(query, self.showEnemyCorpses, self.voteDuration, self.cooldownBetweenVotes, self.maxVotingStartsPerPlayer, self.votingParticipationNeeded, self.enableAssistFunction) then
		print('Failed to execute query: ' .. SQL:Error())
		return
	end
	
	-- Fetch all rows from the table.
	results = SQL:Query('SELECT * FROM mod_settings')

	if not results then
		print('Failed to execute query: ' .. SQL:Error())
		return
	end

	SQL:Close()
end
-- Endregion

-- Region ServerBanner on Loading Screen
		-- also Broadcast ServerSettings on every level loading
function BetterIngameAdmin:OnLevelLoaded(levelName, gameMode, round, roundsPerMap)
	local args = RCON:SendCommand('vars.serverName')
	self.serverName = args[2]
	args = RCON:SendCommand('vars.serverDescription')
	self.serverDescription = args[2]

	if self.loadedModSettings == false then

		if not SQL:Open() then
			return
		end
		
		local query = [[
		  CREATE TABLE IF NOT EXISTS mod_settings (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			showEnemyCorpses BOOLEAN,
			voteDuration INTEGER,
			cooldownBetweenVotes INTEGER,
			maxVotingStartsPerPlayer INTEGER,
			votingParticipationNeeded INTEGER,
			enableAssistFunction BOOLEAN
		  )
		]]
		if not SQL:Query(query) then
		  print('Failed to execute query: ' .. SQL:Error())
		  return
		end
		
		-- Fetch all rows from the table.
		results = SQL:Query('SELECT * FROM mod_settings')

		if not results then
		  print('Failed to execute query: ' .. SQL:Error())
		  return
		end
		
		SQL:Close()

		if #results == 0 then
			print("MODSETTINGS - LIST EMPTY - CREATING LIST")
			self:SQLSaveModSettings()
		end
		if results[1]["showEnemyCorpses"] == 1 then
			self.showEnemyCorpses = true
		else
			self.showEnemyCorpses = false
		end
		self.cooldownBetweenVotes = results[1]["cooldownBetweenVotes"]
		self.votingParticipationNeeded = results[1]["votingParticipationNeeded"]
		self.voteDuration = results[1]["voteDuration"]
		self.maxVotingStartsPerPlayer = results[1]["maxVotingStartsPerPlayer"]
		if results[1]["enableAssistFunction"] == 1 then
			self.enableAssistFunction = true
		else
			self.enableAssistFunction = false
		end
		self.loadedModSettings = true
	end
	
	local syncedBFSettings = ResourceManager:GetSettings("SyncedBFSettings")
	if syncedBFSettings ~= nil then
		syncedBFSettings = SyncedBFSettings(syncedBFSettings)
		if self.enableAssistFunction == true then
			syncedBFSettings.teamSwitchingAllowed = false
		else
			syncedBFSettings.teamSwitchingAllowed = true
		end
	end
	
	self:OnBroadcastServerInfo()
end

function BetterIngameAdmin:OnLevelDestroy()
	self.playerStartedVoteCounter = {}
	local args = RCON:SendCommand('vars.serverName')
	self.serverName = args[2]
	args = RCON:SendCommand('vars.serverDescription')
	self.serverDescription = args[2]
	NetEvents:Broadcast('Info', {self.serverName, self.serverDescription, self.bannerUrl})
end
-- Endregion

-- Region Send information to joining player (send serverInfo, send ServerBanner, if player is admin then send adminrights)
function BetterIngameAdmin:OnAuthenticated(player)
	if self.owner == nil then
		self.owner = player.name
		if not SQL:Open() then
			return
		end
		local query = [[DROP TABLE IF EXISTS server_owner]]
		if not SQL:Query(query) then
		  print('Failed to execute query: ' .. SQL:Error())
		  return
		end
		query = [[
		  CREATE TABLE IF NOT EXISTS server_owner (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			text_value TEXT
		  )
		]]
		if not SQL:Query(query) then
		  print('Failed to execute query: ' .. SQL:Error())
		  return
		end
		query = 'INSERT INTO server_owner (text_value) VALUES (?)'
		if not SQL:Query(query, self.owner) then
		  print('Failed to execute query: ' .. SQL:Error())
		  return
		end
		
		-- Fetch all rows from the table.
		results = SQL:Query('SELECT * FROM server_owner')

		if not results then
		  print('Failed to execute query: ' .. SQL:Error())
		  return
		end

		SQL:Close()
		NetEvents:SendTo('ServerOwnerRights', player)
		NetEvents:SendTo('QuickServerSetup', player)
		self.serverConfig[52] = player.name
		print("ADMIN - SERVER OWNER SET - Player " .. player.name .. " is now server owner.")
	elseif player.name == self.owner then
		NetEvents:SendTo('ServerOwnerRights', player)
		print("ADMIN - SERVER OWNER JOINED - Owner " .. player.name .. " has joined the server.")
	end
	
	NetEvents:SendTo('Info', player, {self.serverName, self.serverDescription, self.bannerUrl})
	
	NetEvents:SendTo('RefreshModSettings', player, {self.showEnemyCorpses, self.voteDuration, self.cooldownBetweenVotes, self.maxVotingStartsPerPlayer, self.votingParticipationNeeded, self.enableAssistFunction})
	
	if self.adminList[player.name] ~= nil then
		NetEvents:SendTo('AdminPlayer', player, self.adminList[player.name])
		print("ADMIN - ADMIN JOINED - Admin " .. player.name .. " has joined the server.")
	end
	NetEvents:SendTo('ServerInfo', player, self.serverConfig)
	if self.enableAssistFunction == true then
		self:CheckQueueAssist()
	end
end
-- Endregion


-- Region Broadcast ServerInfo
	-- gets called on OnLevelLoaded
function BetterIngameAdmin:OnBroadcastServerInfo()
	local args = {}
	local arg = RCON:SendCommand('vars.serverName')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.serverDescription')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.serverMessage')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.gamePassword')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.autoBalance')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.friendlyFire')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.killCam')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.minimap')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.hud')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.3dSpotting')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.miniMapSpotting')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.nameTag')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.3pCam')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.regenerateHealth')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.vehicleSpawnAllowed')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.onlySquadLeaderSpawn')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vu.DestructionEnabled')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vu.DesertingAllowed')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vu.VehicleDisablingEnabled')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vu.HighPerformanceReplication')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vu.SunFlareEnabled')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vu.ColorCorrectionEnabled')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.maxPlayers')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.teamKillCountForKick')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.teamKillValueForKick')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.teamKillValueIncrease')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.teamKillValueDecreasePerSecond')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.teamKillKickForBan')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.idleTimeout')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.idleBanRounds')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.roundStartPlayerCount')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.roundRestartPlayerCount')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.roundLockdownCountdown')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.vehicleSpawnDelay')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.soldierHealth')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.playerRespawnTime')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.playerManDownTime')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.bulletDamage')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.gameModeCounter')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.gunMasterWeaponsPreset')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vu.SuppressionMultiplier')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vu.TimeScale')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vu.SquadSize')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vu.ServerBanner')
	if arg ~= nil and arg[2] ~= nil then
		table.insert(args, arg[2])
	else
		table.insert(args, " ")
	end
	
	
	arg = RCON:SendCommand('mapList.list')
	if arg ~= nil and arg[2] ~= nil then
		table.remove(arg, 1)
		table.insert(args, arg)
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('mapList.getMapIndices')
	if arg ~= nil and arg[2] ~= nil then
		table.remove(arg, 1)
		table.insert(args, arg)
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('mapList.getRounds')
	if arg ~= nil and arg[2] ~= nil then
		table.remove(arg, 1)
		table.insert(args, arg)
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('serverInfo')
	if arg ~= nil and arg[2] ~= nil then
		if arg[9] == "2" then
			table.insert(args, arg[22])
		elseif arg[9] == "4" then
			table.insert(args, arg[24])
		elseif arg[9] == "0" then
			table.insert(args, arg[20])
		end
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.ctfRoundTimeModifier')
	if arg ~= nil and arg[2] ~= nil then
		table.remove(arg, 1)
		table.insert(args, arg)
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vu.FrequencyMode')
	if arg ~= nil and arg[2] ~= nil then
		table.remove(arg, 1)
		table.insert(args, arg)
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('modList.ListRunning')
	if arg ~= nil and arg[2] ~= nil then
		table.remove(arg, 1)
		table.insert(args, arg)
	else
		table.insert(args, " ")
	end
	arg = nil
	arg = RCON:SendCommand('vars.serverOwner')
	if arg ~= nil and arg[2] ~= nil then
		table.remove(arg, 1)
		table.insert(args, arg[1])
	else
		table.insert(args, " ")
	end
	self.serverConfig = args
	NetEvents:Broadcast('ServerInfo', args)
end
-- Endregion

g_BetterIngameAdmin = BetterIngameAdmin()
