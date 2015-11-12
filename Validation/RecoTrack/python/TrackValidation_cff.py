import FWCore.ParameterSet.Config as cms

import SimTracker.TrackAssociatorProducers.trackAssociatorByChi2_cfi 
from SimTracker.TrackAssociatorProducers.quickTrackAssociatorByHits_cfi import *
from SimTracker.TrackAssociation.trackingParticleRecoTrackAsssociation_cfi import *
import Validation.RecoTrack.MultiTrackValidator_cfi
from SimTracker.TrackAssociation.LhcParametersDefinerForTP_cfi import *
from SimTracker.TrackAssociation.CosmicParametersDefinerForTP_cfi import *
from Validation.RecoTrack.PostProcessorTracker_cfi import *
import cutsRecoTracks_cfi

from SimTracker.TrackerHitAssociation.clusterTpAssociationProducer_cfi import *
from SimTracker.VertexAssociation.VertexAssociatorByPositionAndTracks_cfi import *
from PhysicsTools.RecoAlgos.trackingParticleSelector_cfi import trackingParticleSelector as _trackingParticleSelector
from CommonTools.RecoAlgos.sortedPrimaryVertices_cfi import sortedPrimaryVertices as _sortedPrimaryVertices
from CommonTools.RecoAlgos.recoChargedRefCandidateToTrackRefProducer_cfi import recoChargedRefCandidateToTrackRefProducer as _recoChargedRefCandidateToTrackRefProducer

## Track selectors
_algos = [
    "generalTracks",
    "initialStep",
    "lowPtTripletStep",
    "pixelPairStep",
    "detachedTripletStep",
    "mixedTripletStep",
    "pixelLessStep",
    "tobTecStep",
    "jetCoreRegionalStep",
    "muonSeededStepInOut",
    "muonSeededStepOutIn",
]
def _algoToSelector(algo):
    sel = ""
    if algo != "generalTracks":
        sel = algo[0].upper()+algo[1:]
    return "cutsRecoTracks"+sel

def _addSelectorsByAlgo():
    names = []
    seq = cms.Sequence()
    for algo in _algos:
        if algo == "generalTracks":
            continue
        modName = _algoToSelector(algo)
        mod = cutsRecoTracks_cfi.cutsRecoTracks.clone(algorithm=[algo])
        globals()[modName] = mod
        names.append(modName)
        seq += mod
    return (names, seq)
def _addSelectorsByHp():
    seq = cms.Sequence()
    names = []
    for algo in _algos:
        modName = _algoToSelector(algo)
        modNameHp = modName+"Hp"
        if algo == "generalTracks":
            mod = cutsRecoTracks_cfi.cutsRecoTracks.clone(quality=["highPurity"])
        else:
            mod = globals()[modName].clone(quality=["highPurity"])
        globals()[modNameHp] = mod
        names.append(modNameHp)
        seq += mod
    return (names, seq)
def _addSelectorsBySrc(modules, midfix, src):
    seq = cms.Sequence()
    names = []
    for modName in modules:
        modNameNew = modName.replace("cutsRecoTracks", "cutsRecoTracks"+midfix)
        mod = globals()[modName].clone(src=src)
        globals()[modNameNew] = mod
        names.append(modNameNew)
        seq += mod
    return (names, seq)

# Validation iterative steps
(_selectorsByAlgo, tracksValidationSelectorsByAlgo) = _addSelectorsByAlgo()

# high purity
(_selectorsByAlgoHp, tracksValidationSelectorsByAlgoHp) = _addSelectorsByHp()

# BTV-like selection
import PhysicsTools.RecoAlgos.btvTracks_cfi as btvTracks_cfi
cutsRecoTracksBtvLike = btvTracks_cfi.btvTrackRefs.clone()

# Select tracks associated to AK4 jets
import RecoJets.JetAssociationProducers.ak4JTA_cff as ak4JTA_cff
ak4JetTracksAssociatorExplicitAll = ak4JTA_cff.ak4JetTracksAssociatorExplicit.clone(
    jets = "ak4PFJets"
)
from JetMETCorrections.Configuration.JetCorrectors_cff import *
import CommonTools.RecoAlgos.jetTracksAssociationToTrackRefs_cfi as jetTracksAssociationToTrackRefs_cfi
cutsRecoTracksAK4PFJets = jetTracksAssociationToTrackRefs_cfi.jetTracksAssociationToTrackRefs.clone(
    association = "ak4JetTracksAssociatorExplicitAll",
    jets = "ak4PFJets",
    correctedPtMin = 10,
)


## Select signal TrackingParticles, and do the corresponding associations
trackingParticlesSignal = _trackingParticleSelector.clone(
    signalOnly = True,
    chargedOnly = False,
    tip = 1e5,
    lip = 1e5,
    minRapidity = -10,
    maxRapidity = 10,
    ptMin = 0,
)
tpClusterProducerSignal = tpClusterProducer.clone(
    trackingParticleSrc = "trackingParticlesSignal"
)
quickTrackAssociatorByHitsSignal = quickTrackAssociatorByHits.clone(
    cluster2TPSrc = "tpClusterProducerSignal"
)
trackingParticleRecoTrackAsssociationSignal = trackingParticleRecoTrackAsssociation.clone(
    label_tp = "trackingParticlesSignal",
    associator = "quickTrackAssociatorByHitsSignal"
)

# select tracks from the PV
from CommonTools.RecoAlgos.TrackWithVertexRefSelector_cfi import trackWithVertexRefSelector as _trackWithVertexRefSelector
generalTracksFromPV = _trackWithVertexRefSelector.clone(
    src = "generalTracks",
    ptMin = 0,
    ptMax = 1e10,
    ptErrorCut = 1e10,
    quality = "loose",
    vertexTag = "offlinePrimaryVertices",
    nVertices = 1,
    vtxFallback = False,
    zetaVtx = 0.1, # 1 mm
    rhoVtx = 1e10, # intentionally no dxy cut
)
# and then the selectors
(_selectorsFromPV, tracksValidationSelectorsFromPV) = _addSelectorsBySrc([_selectorsByAlgoHp[0]], "FromPV", "generalTracksFromPV")
(_selectorsFromPVStandalone, tracksValidationSelectorsFromPVStandalone) = _addSelectorsBySrc(_selectorsByAlgo+_selectorsByAlgoHp[1:], "FromPV", "generalTracksFromPV")
tracksValidationSelectorsFromPV.insert(0, generalTracksFromPV)


## MTV instances
trackValidator= Validation.RecoTrack.MultiTrackValidator_cfi.multiTrackValidator.clone()

trackValidator.label=cms.VInputTag(
    ["generalTracks"] +
    _selectorsByAlgo +
    _selectorsByAlgoHp +
    [
        "cutsRecoTracksBtvLike",
        "cutsRecoTracksAK4PFJets",
    ])
trackValidator.useLogPt=cms.untracked.bool(True)
trackValidator.dodEdxPlots = True
trackValidator.doPVAssociationPlots = True
#trackValidator.minpT = cms.double(-1)
#trackValidator.maxpT = cms.double(3)
#trackValidator.nintpT = cms.int32(40)

from Configuration.StandardSequences.Eras import eras
if eras.fastSim.isChosen():
    trackValidator.dodEdxPlots = False

# For efficiency of signal TPs vs. signal tracks, and fake rate of
# signal tracks vs. signal TPs
trackValidatorFromPV = trackValidator.clone(
    dirName = "Tracking/TrackFromPV/",
    label = ["generalTracksFromPV"]+_selectorsFromPV,
    label_tp_effic = "trackingParticlesSignal",
    label_tp_fake = "trackingParticlesSignal",
    associators = ["trackingParticleRecoTrackAsssociationSignal"],
    trackCollectionForDrCalculation = "generalTracksFromPV",
    doPlotsOnlyForTruePV = True,
    doPVAssociationPlots = False,
)
trackValidatorFromPVStandalone = trackValidatorFromPV.clone()
trackValidatorFromPVStandalone.label.extend(_selectorsFromPVStandalone)

# For fake rate of signal tracks vs. all TPs, and pileup rate of
# signal tracks vs. non-signal TPs
trackValidatorFromPVAllTP = trackValidatorFromPV.clone(
    dirName = "Tracking/TrackFromPVAllTP/",
    label_tp_effic = trackValidator.label_tp_effic.value(),
    label_tp_fake = trackValidator.label_tp_fake.value(),
    associators = trackValidator.associators.value(),
    doSimPlots = False,
    doSimTrackPlots = False,
)
trackValidatorFromPVAllTPStandalone = trackValidatorFromPVAllTP.clone(
    label = trackValidatorFromPVStandalone.label.value()
)

# For efficiency of all TPs vs. all tracks
trackValidatorAllTPEffic = trackValidator.clone(
    dirName = "Tracking/TrackAllTPEffic/",
    label = [
        "generalTracks",
        _selectorsByAlgoHp[0],
    ],
    doSimPlots = False,
    doRecoTrackPlots = False, # Fake rate of all tracks vs. all TPs is already included in trackValidator
    doPVAssociationPlots = False,
)
trackValidatorAllTPEffic.histoProducerAlgoBlock.generalTpSelector.signalOnly = False
trackValidatorAllTPEffic.histoProducerAlgoBlock.TpSelectorForEfficiencyVsEta.signalOnly = False
trackValidatorAllTPEffic.histoProducerAlgoBlock.TpSelectorForEfficiencyVsPhi.signalOnly = False
trackValidatorAllTPEffic.histoProducerAlgoBlock.TpSelectorForEfficiencyVsPt.signalOnly = False
trackValidatorAllTPEffic.histoProducerAlgoBlock.TpSelectorForEfficiencyVsVTXR.signalOnly = False
trackValidatorAllTPEffic.histoProducerAlgoBlock.TpSelectorForEfficiencyVsVTXZ.signalOnly = False
trackValidatorAllTPEfficStandalone = trackValidatorAllTPEffic.clone(
    label = trackValidator.label.value()
)


# the track selectors
tracksValidationSelectors = cms.Sequence(
    tracksValidationSelectorsByAlgo +
    tracksValidationSelectorsByAlgoHp +
    cutsRecoTracksBtvLike +
    ak4JetTracksAssociatorExplicitAll +
    cutsRecoTracksAK4PFJets
)
tracksValidationTruth = cms.Sequence(
    tpClusterProducer +
    quickTrackAssociatorByHits +
    trackingParticleRecoTrackAsssociation +
    VertexAssociatorByPositionAndTracks
)

tracksValidationTruthSignal = cms.Sequence(
    cms.ignore(trackingParticlesSignal) +
    tpClusterProducerSignal +
    quickTrackAssociatorByHitsSignal +
    trackingParticleRecoTrackAsssociationSignal
)

if eras.fastSim.isChosen():
    tracksValidationTruth.remove(tpClusterProducer)
    tracksValidationTruthSignal.remove(tpClusterProducerSignal)


tracksPreValidation = cms.Sequence(
    tracksValidationSelectors +
    tracksValidationSelectorsFromPV +
    tracksValidationTruth +
    tracksValidationTruthSignal
)
tracksPreValidationStandalone = cms.Sequence(
    tracksPreValidation +
    tracksValidationSelectorsFromPVStandalone
)

# selectors go into separate "prevalidation" sequence
tracksValidation = cms.Sequence(
    trackValidator +
    trackValidatorFromPV +
    trackValidatorFromPVAllTP +
    trackValidatorAllTPEffic
)

tracksValidationStandalone = cms.Sequence(
    ak4PFL1FastL2L3CorrectorChain+
    tracksPreValidationStandalone+
    trackValidator +
    trackValidatorFromPVStandalone +
    trackValidatorFromPVAllTPStandalone +
    trackValidatorAllTPEfficStandalone
)

# 'slim' sequences that only depend on track and tracking particle collections
tracksValidationSelectorsSlim = tracksValidationSelectors.copyAndExclude([cutsRecoTracksBtvLike,ak4JetTracksAssociatorExplicitAll,cutsRecoTracksAK4PFJets])

tracksPreValidationSlim = cms.Sequence(
    tracksValidationSelectorsSlim +
    tracksValidationTruth
)

trackValidatorSlim = trackValidator.clone(
    doPVAssociationPlots = cms.untracked.bool(False),
    dodEdxPlots = False
)
for _label in ["cutsRecoTracksBtvLike", "cutsRecoTracksAK4PFJets"]:
    trackValidatorSlim.label.remove(_label)

tracksValidationSlim = cms.Sequence(
    tracksPreValidationSlim+
    trackValidatorSlim
)
