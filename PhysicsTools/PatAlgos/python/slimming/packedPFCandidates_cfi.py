import FWCore.ParameterSet.Config as cms

packedPFCandidates = cms.EDProducer("PATPackedCandidateProducer",
    inputCollection = cms.InputTag("particleFlow"),
    inputCollectionFromPVLoose = cms.InputTag("pfNoPileUpJME"),
    inputCollectionFromPVTight = cms.InputTag("pfNoPileUp"),
    inputVertices = cms.InputTag("offlineSlimmedPrimaryVertices"),
    minPtForTrackProperties = cms.double(0.8)	
)
