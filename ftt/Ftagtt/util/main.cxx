/**
 * @brief This code extracts ntuples out of FTAG1 DAODs
 * @authors Emily Anne Thompson, Soumyananda Goswami
 * Initialize environment before running, on any machine that has cvmfs access:
 * `setupATLAS -q`
 * `asetup AnalysisBase,21.2.125`
 * To run:
 * `root -l -b -q main.C(args)`
 */


#include <string>
#include <vector>
#include <iostream>
#include <stdlib.h>
#include <map>
#include <cmath>

#include <TROOT.h>
#include <TFile.h>
#include <TTree.h>
#include <TChain.h>
#include <TBranch.h>

#include "xAODEventInfo/EventInfo.h"
#include "xAODTruth/TruthEventContainer.h"
#include <xAODTruth/TruthParticleContainer.h>
#include "xAODRootAccess/TEvent.h"
//#include <xAODTruth/TruthParticle.h>
//#include <xAODTruth/TruthVertex.h>
//#include <xAODTruth/TruthEvent.h>
void fillChildMap(std::map<std::pair<int, int>, const xAOD::TruthParticle *> *childMap, const xAOD::TruthParticle *parent)
{

  auto parent_pdgId = parent->pdgId();
  if (!parent->decayVtx())
  {
  } // do nothing
  else
  {
    for (size_t i = 0; i < parent->decayVtx()->nOutgoingParticles(); i++)
    {

      const xAOD::TruthParticle *child = parent->decayVtx()->outgoingParticle(i);
      if(!child) continue;
      if (child)
      {
        // if (child->status()==1 ){
        // if (fabs(child->pdgId())==1000022 || !(fabs(child->pdgId())>1e6 && fabs(child->pdgId())<3e6)){
        if (fabs(child->pdgId()) != parent_pdgId)
        {
          childMap->insert(std::pair<std::pair<int, int>, const xAOD::TruthParticle *>(std::make_pair(child->pdgId(), child->barcode()), child));
        }
        else
        {
          fillChildMap(childMap, child);
        }
      }
    }
  }
 // return;
}

int main(int argc, char *argv[])
{
  // Set Debug state
  bool DEBUG = false;
  std::string outfile;
  //outfile=argv[2];

  // Provide Output File Name
  TFile *f = new TFile("output.root", "RECREATE");

  // Split input DAOD FTAG1 file list on the Grid by ','
  std::string argStr = argv[1];
  std::vector<std::string> inputFileNames;

  for (size_t i = 0, n; i <= argStr.length(); i = n + 1)
  {
    n = argStr.find_first_of(',', i);
    if (n == std::string::npos)
      n = argStr.length();
    std::string tmp = argStr.substr(i, n - i);
    inputFileNames.push_back(tmp);
  }

  // Initialize xAOD stuff
  auto xaodEvent = new xAOD::TEvent(xAOD::TEvent::kClassAccess);
  TFile *inFile = 0;

  // Provide Tree name for the ntuples/branches to be written out
  TTree *tree = new TTree("FTAG1TruthTuple", "FTAG Truth Information");

  int eventNumber;
  tree->Branch("EventNumber", &eventNumber);

  // Declare the branches
  std::vector<float> DV_R;
  std::vector<float> n1_lifetime;
  std::vector<float> n1pt;

  // Initialize the branches
  tree->Branch("DV_R", &DV_R);
  tree->Branch("n1_lifetime", &n1_lifetime);
  tree->Branch("n1pt", &n1pt);

  // Loop over filenames
  for (const auto &inFileName : inputFileNames)
  {
    // Delete any previous input files initialized in the inFile array
    delete inFile;

    // Open DAOD FTAG1 file as READ only
    inFile = TFile::Open(inFileName.c_str(), "READ");
    if (!xaodEvent->readFrom(inFile).isSuccess())
    {
      throw std::runtime_error("Could not connect TEvent to file!");
    }

    // Get Number of Events, must equal what you specified in the MC production, before cuts
    Long64_t numEntries = xaodEvent->getEntries();
    std::cout << "Num Event Entries=" << numEntries << std::endl;

    // if (DEBUG) numEntries = 20; //This is if you need fewer events to catch errors.
    // Loop over events
    for (Long64_t index = 0; index < numEntries; index++)
    {

      // Get n-th event
      Long64_t entry = xaodEvent->getEntry(index);
      if (entry < 0)
      {
        std::cout << "Entry less than 0!" << std::endl;
      }
      if (DEBUG)
        std::cout << "================= New event =====================" << std::endl
                  << std::endl;

      // Get basic event info
      const xAOD::EventInfo *eventInfo = 0;
      if (!xaodEvent->retrieve(eventInfo, "EventInfo").isSuccess())
      {
        throw std::runtime_error("Cannot read Event Info");
      }

      // Get truth particles
      /**
       * For Truth Particle Container, Please see: https://ucatlas.github.io/RootCoreDocumentation/2.4.28/dd/dc2/classxAOD_1_1TruthParticle__v1.html
       * For Truth Vertex Container, Please see: https://ucatlas.github.io/RootCoreDocumentation/2.4.28/d8/dfa/classxAOD_1_1TruthVertex__v1.html
       */
      const xAOD::TruthParticleContainer *truthparticles = 0;
      if (xaodEvent->contains<xAOD::TruthParticleContainer>("TruthParticles"))
      {
        if (!xaodEvent->retrieve(truthparticles, "TruthParticles").isSuccess())
        {
          throw std::runtime_error("Could not retrieve truth particles");
        }
      }
      // if (DEBUG)
      std::cout << "Number of truth particles in this event are: " << truthparticles->size() << std::endl;

      std::vector<size_t> hard_int = {};

      // Check the particles produced directly from hard interactions
      if (DEBUG)
        std::cout << "Particles produced in hard interaction: " << std::endl;
      for (size_t tp = 0; tp < truthparticles->size(); tp++)
      {
        const auto SP = truthparticles->at(tp); // Get Selected truth particle at the given iterator index

        /**
         * The following lines of code select particles by their PDGID
         * Please see: https://pdg.lbl.gov/2007/reviews/montecarlorpp.pdf
         * The particles are counted by their respective type per event
         * Their pts are also filled up, where required
         */
        if (fabs(SP->pdgId()) == 1000022 && SP->status() == 22)
        {
          hard_int.push_back(tp);
          n1pt.push_back(1e-3 * SP->pt());

          if (DEBUG)
            std::cout << "pdgID: " << SP->pdgId() << ", mass: " << SP->m() / 1000. << ", decays? " << SP->hasDecayVtx() << ", status: " << SP->status() << std::endl;
          if (DEBUG)
            std::cout << "Production vertex: (" << SP->prodVtx()->x() << ", " << SP->prodVtx()->y() << ", " << SP->prodVtx()->z() << ")" << std::endl;
          if (DEBUG)
            std::cout << "Decay vertex: (" << SP->decayVtx()->x() << ", " << SP->decayVtx()->y() << ", " << SP->decayVtx()->z() << ")" << std::endl;
          float decayR = sqrt(pow(((SP->prodVtx()->x()) - (SP->decayVtx()->x())), 2.) + pow(((SP->prodVtx()->y()) - (SP->decayVtx()->y())), 2.) + pow(((SP->prodVtx()->z()) - (SP->decayVtx()->x())), 2.));
          DV_R.push_back(0.1 * decayR);

          // Is in seconds, because Physics Short was used
          float lifetimeLab = (SP->decayVtx()->v4().Vect()).Mag() / (SP->p4().Beta() * SP->p4().Gamma() * TMath::C()) / 1000.;
          if (DEBUG)
            std::cout << "lifetime: " << lifetimeLab << std::endl
                      << std::endl;
          if (lifetimeLab > 0.)
            n1_lifetime.push_back(lifetimeLab);
        }
      } // end of loop over truth particles

      if (DEBUG)
        std::cout << std::endl
                  << "Stable particles from hard interaction decays: " << std::endl;

      // The : stands for fancy C++ iterator and loops (in this case) over all hard interaction particles
      for (auto tp : hard_int)
      {
        const auto SP = truthparticles->at(tp);

        std::map<std::pair<int, int>, const xAOD::TruthParticle *> childMap;
        fillChildMap(&childMap, SP);
        std::vector<const xAOD::TruthParticle *> uniqueChildren;
        typedef std::map<std::pair<int, int>, const xAOD::TruthParticle_v1 *>::const_iterator MapIterator;
        for (MapIterator iter = childMap.begin(); iter != childMap.end(); iter++)
        {
          uniqueChildren.push_back(iter->second);
          if (DEBUG)
            std::cout << "Daughter pdgId: " << iter->second->pdgId() << ", mass: " << iter->second->m() / 1000. << ", pt: " << iter->second->pt() / 1000. << std::endl;
        }
      }
      tree->Fill();
      n1_lifetime.clear();
    } // end of entries loop
    inFile->Close();
  } // end of filenames loop
  f->cd();
  f->WriteObject(tree, "FTAG1TruthTuple");
  tree->SetDirectory(f);
  tree->Write();
  f->Close();
return 0;
}
