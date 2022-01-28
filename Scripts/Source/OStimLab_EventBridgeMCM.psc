Scriptname OStimLab_EventBridgeMCM extends SKI_ConfigBase hidden 

OStimLab_EventBridge property eventBridge auto

int property EnableSceneStartEventOid auto
int property EnableSceneEndEventOid auto
int property EnableSceneOrgasmEventOid auto
int property EnableAnimationChangeEventOid auto

int function GetVersion()
	return 1
endFunction

Event OnConfigInit()
    ModName = "OStimLab Event Bridge"
    Pages = new String[1]
    Pages[0] = "Event Settings"
EndEvent

event OnPageReset(string page)
    if (page == "" || page == "Event Settings")
        EnableSceneStartEventOid = AddToggleOption("Animation Start Event", eventBridge.EnableSceneStartEvent)
        EnableSceneEndEventOid = AddToggleOption("Animation End Event", eventBridge.EnableSceneEndEvent)
        EnableSceneOrgasmEventOid = AddToggleOption("Orgasm Event", eventBridge.EnableSceneOrgasmEvent)
        EnableAnimationChangeEventOid = AddToggleOption("Animation Change Event", eventBridge.EnableAnimationChangeEvent)
    EndIf
endEvent

event OnOptionSelect(int optionId)
    if(CurrentPage == "Event Settings" || CurrentPage == "")
        if(optionId == EnableSceneStartEventOid)
            eventBridge.EnableSceneStartEvent = !eventBridge.EnableSceneStartEvent 
            SetToggleOptionValue(EnableSceneStartEventOid, eventBridge.EnableSceneStartEvent)
        elseif (optionId == EnableSceneEndEventOid)
            eventBridge.EnableSceneEndEvent = !eventBridge.EnableSceneEndEvent 
            SetToggleOptionValue(EnableSceneEndEventOid, eventBridge.EnableSceneEndEvent)
        elseif (optionId == EnableSceneOrgasmEventOid)
            eventBridge.EnableSceneOrgasmEvent = !eventBridge.EnableSceneOrgasmEvent 
            SetToggleOptionValue(EnableSceneOrgasmEventOid, eventBridge.EnableSceneOrgasmEvent)
        elseif (optionId == EnableAnimationChangeEventOid)
            eventBridge.EnableAnimationChangeEvent = !eventBridge.EnableAnimationChangeEvent 
            SetToggleOptionValue(EnableAnimationChangeEventOid, eventBridge.EnableAnimationChangeEvent)
        EndIf
    EndIf
endevent

event OnOptionHighlight(int optionId)
    if(CurrentPage == "$EVENT_SETTINGS")
        if(optionId == EnableSceneStartEventOid)
            SetInfoText("If Enabled will Trigger a Sexlab 'AnimationStart' event when ostim_start is received")
        elseif(optionId == EnableSceneEndEventOid)
            SetInfoText("If Enabled will Trigger a Sexlab 'AnimationEnd' event when ostim_end is received")
        elseif(optionId == EnableSceneOrgasmEventOid)
            SetInfoText("If Enabled will Trigger a Sexlab 'OrgasmStart' (OR SexLabOrgasmSeparate if SLSO specified) AND SexLabOrgasm event when ostim_orgasm is received")
        elseif(optionId == EnableSceneOrgasmEventOid)
            SetInfoText("If Enabled will Trigger a Sexlab 'AnimationChange' event when ostim_scenechanged is received")
        EndIf
    EndIf
endevent