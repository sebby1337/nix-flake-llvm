{ pkgs ? import <nixpkgs> {} }:

let
  llvm = pkgs.llvmPackages_16.llvm;

  mkOptStage = { name, input, passes, output }:
    pkgs.writeShellScriptBin "stage-${name}" ''
      ${llvm}/bin/opt \
        -load-pass-plugin=$CUSTOM_PASSES_PATH \
        ${toString (lib.concatStringsSep " " passes)} \
        -S ${input} \
        -o ${output}
    '';


  stage1 = mkOptStage {
    name = "initial";
    input = "./main.ll";
    passes = [
      "-passes=mem2reg"
      "-passes=instcombine"
      "-passes=simplifycfg"
    ];
    output = "./stage1.ll";
  };

  stage2 = mkOptStage {
    name = "aggressive";
    input = "./stage1.ll";
    passes = [
      "-passes=gvn"
      "-passes=licm"
      "-passes=loop-unroll"
      "-passes=custom-lsr"
    ];
    output = "./stage2.ll";
  };

  stage3 = mkOptStage {
    name = "final";
    input = "./stage2.ll";
    passes = [
      "-passes=dce"
      "-passes=inline"
    ];
    output = "./optimised.ll";
  };

in {
  inherit stage1 stage2 stage3;

  pipeline = pkgs.writeShellScriptBin "run-pipeline" ''
    export CUSTOM_PASSES_PATH="$(pwd)/src/pass/build/libCustomPasses.so"
    
    echo "Starting optimisation pipeline..."
    
    ${stage1}/bin/stage-initial
    ${stage2}/bin/stage-aggressive
    ${stage3}/bin/stage-final
    
    echo "Pipeline complete. Optimised IR written to optimised.ll"
  '';
}
