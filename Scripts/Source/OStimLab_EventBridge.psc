Scriptname OStimLab_EventBridge extends Quest Hidden 

SexLabFramework Property SexLab Auto

OSexIntegrationMain property OStim auto

;Ostim Events:

;ostim_start
;ostim_end
;ostim_totalend
;ostim_animationchanged
;ostim_scenechanged
;ostim_spank
;ostim_orgasm


;Sexlab Events:
;AnimationStart
;AnimationEnd
;StageStart
;StageEnd
;OrgasmStart
;OrgasmEnd
;SexlabOrgasm
;AnimationChange

;SLSO event
;SexLabOrgasmSeparate


;TrackedTags SL:
;Anal
;Vaginal
;Masturbation
;Blowjob, Oral
;Boobjob
;Handjob
;Footjob
;Fisting
;Cunnilingus

bool property EnableSceneStartEvent = true auto
bool property EnableSceneEndEvent = true auto
bool property EnableSceneOrgasmEvent = true auto
bool property EnableAnimationChangeEvent = false auto

; TO make our live easier we only track main ostim thread
; We create a dummy SexlabThread to dump scene data into for the generated sexlab event consumers to pull from
sslThreadModel ActiveSexlabThread
bool bThreadPendingCleanup

string[] ScenePerformedTags

event OnInit()
	Log("OStimLab Event Bridge Installed")
	Debug.Notification("OStimLab Event Bridge Installed")
    OnGameLoad()
endevent

event OnGameLoad()
	Log("OStimLab Event Bridge Loaded")
    RegisterForModEvent("ostim_start", "OStimStart")
    RegisterForModEvent("ostim_end", "OStimEnd")
    RegisterForModEvent("ostim_orgasm", "OStimOrgasm")

    RegisterForModEvent("ostim_scenechanged", "OStimSceneChanged")

    ;Threads dont persist across game loads so should be safe to do this here??? 
    ;@TODO: I HAVE NO GODAMN IDEA
    ActiveSexlabThread = none
    bThreadPendingCleanup = false
endevent

Event OStimStart(String EventName, String Args, Float Nothing, Form Sender)
    if(!OStim)
        Log(" FATAL - Unable to find OStim")
        return
    endif

    ;Only Process Events if sexlab enabled
    ;NOTE: If Sexlab not installed (Ie enabled but not installed) this returns true but will throw errors later on
    if(!SexLabUtil.SexLabIsReady())
        Log("Sexlab  not ready, Aborting")
        return
    endif

    ;If we already have a populated sexlab thread, clean it up
    if(ActiveSexlabThread)
        Sexlab.ThreadSlots.StopThread(ActiveSexlabThread as sslThreadController)
        if(!bThreadPendingCleanup)
            Log("OStimStart: ERROR - ActiveSexlabThread Set and not pending cleanup")
        endif
        ActiveSexlabThread = none
    endif

    ;Trigger a sexlab start event
    GenerateSexlabThread()
    if(ActiveSexlabThread)
        if(EnableSceneStartEvent)
            Log("Sending AnimationStart Event")
            ActiveSexlabThread.SendThreadEvent("AnimationStart")
        endif

        ;We need to Register a heartbeat update to keep this sexlab thread alive while the ostim scene runs
        RegisterForSingleUpdate(30)
    endif
endevent

Event OStimEnd(String EventName, String Args, Float Nothing, Form Sender)
    ;Only Process Events if sexlab enabled
    if(!SexLabUtil.SexLabIsReady())
        return
    endif

    ;On Ostim End we send sexlab end event, and set the Sexlab thread to frozen (so it can be reclaimed by sexlab.)
    ;Unfortunately no way to do that directly, But should be able to put it in a delay queue to release thread after 10 seconds (like how sexlab does it) to allow the hooks to recieve events

    if(ActiveSexlabThread)
        ;Update The animation tags to have tags based off actions performed this scene
        UpdateAnimationTags()
        ;Send Stats about participants to Sexlab Stats
        RecordStatsForParticipants()

        if(EnableSceneEndEvent)
            Log("Sending AnimationEnd Event")
            ActiveSexlabThread.SendThreadEvent("AnimationEnd")
        endif
        ; Need to queue up cleanup of the sexlab thread. Wait 10 seconds sso that hooks have a chance to use thread data
        bThreadPendingCleanup = true
        RegisterForSingleUpdate(10)
    endif
    
    ScenePerformedTags = PapyrusUtil.StringArray(0)
endevent

Event OStimOrgasm(String EventName, String Args, Float Nothing, Form Sender)
    ;Only Process Events if sexlab enabled
    if(!SexLabUtil.SexLabIsReady())
        return
    endif

    ; On Orgasm we need to send the SexlabOrgasm event, And Either OrgasmStart/End (Both To catch all mods) or the SLSO SexLabOrgasmSeparate if installed
    
    ;Update The animation tags to have tags based off actions performed this scene
    UpdateAnimationTags()

    if(ActiveSexlabThread && EnableSceneOrgasmEvent)
        actor orgasmer = ostim.GetMostRecentOrgasmedActor()
        ;Need to manually create SexlabOrgasm event since special case
        int eid = ModEvent.Create("SexLabOrgasm")
        if(eid)
            ;Just send with 100 Enjoyment and 1 orgasm (I dont think many mods actually utilize those event fields)
            ModEvent.PushForm(eid, orgasmer)
            ModEvent.PushInt(eid, 100) ; Enjoyment Parameter
            ModEvent.PushInt(eid, 1) ; Orgasms Parameter
            ModEvent.Send(eid)
            Log("Sending SexLabOrgasm Event")
        endif

        ;If SLSO installed send SexLabOrgasmSeparate otherwise OrgasmStart/End
        If Game.GetModByName("SLSO.esp") != 255
            eid = ModEvent.Create("SexLabOrgasmSeparate")
            if eid
                ModEvent.PushForm(eid, orgasmer) ; target
                ModEvent.PushInt(eid, ActiveSexlabThread.tid) ;threadid
                ModEvent.Send(eid)
                Log("Sending SexLabOrgasmSeparate Event")
            endif
        Else
            ;Send both start and end
            ActiveSexlabThread.SendThreadEvent("OrgasmStart")
            ActiveSexlabThread.SendThreadEvent("OrgasmEnd")
            Log("Sending OrgasmStart AND OrgasmEnd Event")
        endif
    endif
endevent

Event OStimSceneChanged(String EventName, String Args, Float Nothing, Form Sender)
    ;Only Process Events if sexlab enabled
    if(!SexLabUtil.SexLabIsReady())
        return
    endif
    
    string TagToAdd = ""
    ;On Scene Change add to the tag array to indicate what we are doing
    string cClass = OStim.GetCurrentAnimationClass()

    if(cclass == "Sx") ;Sex
        TagToAdd = "Vaginal"
    elseif(cclass == "An") ;Anal
        TagToAdd = "Anal"
    elseif(cclass == "Boj" || cclass == "BoF") ;Boobjob
        TagToAdd = "Boobjob"
    elseif(cclass == "VJ") ;Cunnilingus
        TagToAdd = "Cunnilingus,Oral"
    elseif(cclass == "HJ" || cclass == "ApHJ" || cclass == "DHJ") ;Handjob
        TagToAdd = "Handjob"
    elseif(cclass == "Cr" || cclass == "Pf1" || cclass == "Pf2") ;Fingering    
        TagToAdd = "Fisting"
    elseif(cclass == "BJ" || cclass == "ApPJ" || cclass == "SJ" || cclass == "hhPJ" || cclass == "hhBJ")    ;Blowjob
        TagToAdd = "Blowjob,Oral"
    elseif(cclass == "Po" || cclass == "HhPo") ;Masturbation
        TagToAdd = "Masturbation"
    elseif(cclass == "VBJ" || cclass == "VHJ") ;69
        TagToAdd = "69"
    elseif(cclass == "FJ") ;Footjob
        TagToAdd = "Footjob"
    endif

    if(TagToAdd != "" && PapyrusUtil.CountString(ScenePerformedTags, TagToAdd) == 0)
        ScenePerformedTags = PapyrusUtil.PushString(ScenePerformedTags, TagToAdd)
    endif

    if(EnableSceneEndEvent)
        UpdateAnimationTags()
        Log("Sending AnimationChange Event")
        ActiveSexlabThread.SendThreadEvent("AnimationChange")
    endif
endevent

bool function GenerateSexlabThread()
    if(ActiveSexlabThread != none)
        Debug.MessageBox("OStimLab Event Bridge - Trying to Generate a new Sexlab Thread without Cleaning up old thread.")
        Log("[FATAL] - Generating Sexlab Thread when trackign existing thread. FAILED TO GENERATE SEXLAB EVENT")
        return false;
    endif

    ActiveSexlabThread = SexLab.NewThread()
    if(!ActiveSexlabThread)
        Log("Failed to claim a sexlab thread")
        return false;
    endif

    ActiveSexlabThread.AddTag("OStimLab")

	Actor[] ostimActors = SexLabUtil.MakeActorArray(OStim.GetDomActor(), OStim.GetSubActor(), OStim.GetThirdActor())

    Actor victim = none
    if(OStim.IsSceneAggressiveThemed())
        victim = OStim.GetSubActor()
        if(!OStim.IsVictim(victim))
            victim = Ostim.GetDomActor()
            if(!OStim.IsVictim(victim))
                victim = none
            endif
        endif
    endif

    if(!ActiveSexlabThread.AddActors(ostimActors, victim))
        Log("Failed to add some actors into Sexlab animation Thread")
    endif

    
    ActiveSexlabThread.Animation =  GenerateSexlabAnimation()

    Log("Generated Sexlab Thread W/ Anim: " + ActiveSexlabThread.Animation)
    return true
endfunction

function UpdateAnimationTags()
    ;Update Anim Tags
    sslBaseAnimation anim = Sexlab.GetAnimationObject("OStimLab_TransientAnim")
    if(!anim)
        Log("UpdateAnimationTags: Transient Anim Not Found, Failed to update Anim")
        return
    endif

    string newTags = "OStim"
    if(OStim.IsSceneAggressiveThemed())
        newTags = newTags + ",Aggressive"
    endif
    int i = 0
    while(i < ScenePerformedTags.Length)
        newTags = newTags + "," + ScenePerformedTags[i]
        i += 1
    endwhile
    Log("Updated OStimLab Transient Anim with Tags: " + newTags + " for animation: " + anim)
    anim.SetTags(newTags)
    anim.Save(-1)
endfunction

event OnUpdate()
    ;Here we want keep the sexlab thread alive if we are in an ostim scene
    if(ActiveSexlabThread && ActiveSexlabThread.HasTag("OStimLab"))
        if(bThreadPendingCleanup)
            ;cleanup sexlab thread
            Sexlab.ThreadSlots.StopThread(ActiveSexlabThread as sslThreadController)
            ActiveSexlabThread = none
            ;Release the animation so it doesnt get picked up by sexlab
            Sexlab.ReleaseAnimationObject("OStimLab_TransientAnim")
            bThreadPendingCleanup = false
        else
            ;Refresh the update for the sexlab thread if still in making state (Since thats where it should remain within if its within our control)
            ActiveSexlabThread.RegisterForSingleUpdate(60)
            RegisterForSingleUpdate(30)
        endif
    endif
endevent

function RecordStatsForParticipants()
    if(OStim.GetDomActor())
        RecordStatsForOStimActor(Ostim.GetDomActor())
    endif
    if(OStim.GetSubActor())
        RecordStatsForOStimActor(Ostim.GetSubActor())
    endif
    if(OStim.GetThirdActor())
        RecordStatsForOStimActor(Ostim.GetThirdActor())
    endif
endfunction

function RecordStatsForOStimActor(Actor act)
    int bestRelation = 0
    
    float currentTime = Utility.GetCurrentRealTime()
    float oStimDuration = OStim.GetTimeSinceStart()
    
    Actor victimRef = ActiveSexlabThread.VictimRef
    if OStim.IsVictim(act)
        victimRef = act
    endIf

    sslActorStats.RecordThread(act, Sexlab.GetGender(act), bestRelation, currentTime - oStimDuration, currentTime, Utility.GetCurrentGameTime(), ActiveSexlabThread.HasPlayer, victimRef, ActiveSexlabThread.Genders, ActiveSexlabThread.SkillXP)
endfunction

function Log(string msg) global
    Debug.Trace("---OStimLab--- " + msg)
endfunction

sslBaseAnimation function GenerateSexlabAnimation()
    if(!SexlabUtil.SexLabIsReady())
        Log("Sexlab is not ready, Animation not created")
        return none
    endif
    
    return Sexlab.GetSetAnimationObject("OStimLab_TransientAnim", "CreateAnim", self)
endfunction

function CreateAnim()
    sslBaseAnimation Anim = SexLab.GetAnimationObject("OStimLab_TransientAnim")
    if(anim == none)
        Log("Failed To Populate Anim. Null")
        return none
    endif
    anim.AddTag("OStimLab")

    int a1 = anim.AddPosition(1)
    anim.AddPositionStage(a1, "OStimLab_TransientAnim_1", 0)
    anim.SetStageTimer(1, 10)

    anim.Save(-1)
endfunction