#include "llvm/Pass.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/Transforms/IPO/PassManagerBuilder.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

namespace {

/*
 * 
 * this pass does specialised loop strength reduction by:
 *
 * 1. identifying multiply operations inside loops where one operand is loop invariant
 * 2. converting these multiplications into additions using a running accumulator
 * 3. hoisting loop invariant calculations outside the loop
 *
 * example transformation:
 * before:
 *   for(i = 0; i < n; i++) {
 *     x = a * i; 
 *   }
 *
 * after:
 *   acc = 0;
 *   for(i = 0; i < n; i++) {
 *     x = acc;
 *     acc = acc + a;
 *   }
 */
struct CustomLoopStrengthReduction : public FunctionPass {
  static char ID;
  CustomLoopStrengthReduction() : FunctionPass(ID) {}

  bool isLoopInvariant(Value *V, const Loop *L) {
    if (Instruction *I = dyn_cast<Instruction>(V)) {
      return L->isLoopInvariant(I);
    }
    return true;
  }

  bool runOnFunction(Function &F) override {
    bool Modified = false;
    LLVMContext &Context = F.getContext();

    LoopInfo &LI = getAnalysis<LoopInfoWrapperPass>().getLoopInfo();

    for (Loop *L : LI) {
      SmallVector<BinaryOperator*, 8> MulsToTransform;

      for (BasicBlock *BB : L->blocks()) {
        for (Instruction &I : *BB) {
          if (BinaryOperator *BO = dyn_cast<BinaryOperator>(&I)) {
            if (BO->getOpcode() == Instruction::Mul) {
              Value *Op0 = BO->getOperand(0);
              Value *Op1 = BO->getOperand(1);

              if (isLoopInvariant(Op0, L) != isLoopInvariant(Op1, L)) {
                MulsToTransform.push_back(BO);
              }
            }
          }
        }
      }

      for (BinaryOperator *MulOp : MulsToTransform) {
        IRBuilder<> Builder(L->getLoopPreheader()->getTerminator());
        
        Value *Accumulator = Builder.CreateAlloca(MulOp->getType());
        Builder.CreateStore(ConstantInt::get(MulOp->getType(), 0), Accumulator);

        Value *InvariantOp = isLoopInvariant(MulOp->getOperand(0), L) ? 
                            MulOp->getOperand(0) : MulOp->getOperand(1);

        IRBuilder<> MulBuilder(MulOp);
        Value *LoadedAcc = MulBuilder.CreateLoad(MulOp->getType(), Accumulator);
        MulOp->replaceAllUsesWith(LoadedAcc);

        Value *NewAcc = MulBuilder.CreateAdd(LoadedAcc, InvariantOp);
        MulBuilder.CreateStore(NewAcc, Accumulator);

        Modified = true;
      }
    }

    return Modified;
  }

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.addRequired<LoopInfoWrapperPass>();
    AU.setPreservesCFG();
  }
};

}

char CustomLoopStrengthReduction::ID = 0;

static RegisterPass<CustomLoopStrengthReduction> 
X("custom-lsr", "Custom Loop Strength Reduction Pass");

static RegisterStandardPasses Y(
  PassManagerBuilder::EP_EarlyAsPossible,
  [](const PassManagerBuilder &Builder,
     legacy::PassManagerBase &PM) { PM.add(new CustomLoopStrengthReduction()); });
