{ pkgs ? import <nixpkgs> {} }:

let
  llvm = pkgs.llvmPackages_16.llvm;

  mkOptStage = { name, input, passes, output, enableCustomPass ? true }:
    pkgs.writeShellScriptBin "stage-${name}" ''
      if [ -f ${output} ]; then
        echo "Using cached ${output}"
      else
        ${llvm}/bin/opt \
          ${if enableCustomPass then "-load-pass-plugin=$CUSTOM_PASSES_PATH" else ""} \
          ${toString (lib.concatStringsSep " " passes)} \
          -S ${input} \
          -o ${output}
      fi
    '';

  stages = {
    stage1 = mkOptStage {
      name = "initial";
      input = "./main.ll";
      passes = [
        "-passes=mem2reg"
        "-passes=instcombine"
        "-passes=simplifycfg"
      ];
      output = "./stage1.ll";
      enableCustomPass = false;
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
      enableCustomPass = true;
    };

    stage3 = mkOptStage {
      name = "final";
      input = "./stage2.ll";
      passes = [
        "-passes=dce"
        "-passes=inline"
      ];
      output = "./optimized.ll";
      enableCustomPass = false;
    };
  };

  pipeline = pkgs.writeShellScriptBin "run-pipeline" ''
    export CUSTOM_PASSES_PATH="$(pwd)/src/pass/build/libCustomPasses.so"
    
    for stage in ${toString (lib.concatStringsSep " " (builtins.attrNames stages))}; do
      ${stages}.${stage}/bin/${"stage-${stage}"}
    done
    
    echo "Pipeline complete. Optimised IR written to optimized.ll"
  '';

in {
  inherit stages pipeline;
}
