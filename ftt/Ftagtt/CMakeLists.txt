# Declare the package's dependencies:
atlas_subdir( Ftagtt )
# atlas_depends_on_subdirs( PUBLIC
#                          GaudiKernel
#                          PRIVATE
#                          Event/xAOD/xAODEventInfo
#                          Event/xAOD/xAODEventShape
#                          Event/xAOD/xAODTruth		  
#)
atlas_depends_on_subdirs(PUBLIC
                          GaudiKernel
                         PRIVATE
						  Control/AthenaBaseComps
                          Event/xAOD/xAODEventInfo
						  Event/xAOD/xAODEventShape
						  Event/xAOD/xAODTruth
						  Event/xAOD/xAODBase
						  Event/xAOD/xAODCore
)

set(CMAKE_CXX_FLAGS "-fpermissive -std=c++11")

set(LINK_LIBRARIES
  AthLinks
  ROOT
  xAODCore
  xAODBase
  xAODRootAccess
  xAODTruth
  AsgTools
  )
# External dependencies:
#find_package( ROOT COMPONENTS Core Tree MathCore Hist RIO pthread )
find_package( ROOT )
# Component(s) in the package:
atlas_add_executable( extractinfo 
                      util/main.cxx
					  INCLUDE_DIRS ${ROOT_INCLUDE_DIRS}
					  LINK_LIBRARIES ${ROOT_LIBRARIES} xAODBTagging xAODEventInfo xAODEventShape xAODJet xAODMuon xAODTracking xAODTrigger xAODTruth TrackVertexAssociationToolLib ParticleJetToolsLib JetSubStructureUtils PileupReweightingLib JetInterface TrigDecisionToolLib  InDetTrackSystematicsToolsLib
					  )
atlas_add_component(Ftagtt
  Ftagtt/*
  src/main.cxx
  INCLUDE_DIRS ${ROOT_INCLUDE_DIRS}
  LINK_LIBRARIES ${ROOT_LIBRARIES} xAODBTagging xAODEventInfo xAODEventShape xAODJet xAODMuon xAODTracking xAODTrigger xAODTruth TrackVertexAssociationToolLib ParticleJetToolsLib JetSubStructureUtils PileupReweightingLib JetInterface   TrigDecisionToolLib  InDetTrackSystematicsToolsLib)

atlas_install_scripts(
  grid/grid-submit.sh
  #grid/ftag-grid-nm.sh
  #grid/ftag-grid-sub.sh
)

