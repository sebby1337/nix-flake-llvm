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

  profiles = {
    light = {
      stage1 = mkOptStage {
        name = "light-initial";
        input = "./main.ll";
        passes = ["-passes=mem2reg"];
        output = "./light-stage1.ll";
      };
      stage2 = mkOptStage {
        name = "light-final";
        input = "./light-stage1.ll";
        passes = ["-passes=dce"];
        output = "./optimized.ll";
      };
    };

    aggressive = {
      stage1 = mkOptStage {
        name = "aggressive-initial";
        input = "./main.ll";
        passes = [
          "-passes=mem2reg"
          "-passes=instcombine"
          "-passes=simplifycfg"
        ];
        output = "./aggressive-stage1.ll";
      };
      stage2 = mkOptStage {
        name = "aggressive-final";
        input = "./aggressive-stage1.ll";
        passes = [
          "-passes=gvn"
          "-passes=licm"
          "-passes=loop-unroll"
          "-passes=inline"
        ];
        output = "./optimized.ll";
      };
    };

    custom = {
      stage1 = mkOptStage {
        name = "custom-initial";
        input = "./main.ll";
        passes = [
          "-passes=mem2reg"
          "-passes=custom-pass"
        ];
        output = "./custom-stage1.ll";
      };
      stage2 = mkOptStage {
        name = "custom-final";
        input = "./custom-stage1.ll";
        passes = ["-passes=dce"];
        output = "./optimized.ll";
      };
    };
  };

  pipeline = profile: pkgs.writeShellScriptBin "run-pipeline-${profile}" ''
    export CUSTOM_PASSES_PATH="$(pwd)/src/pass/build/libCustomPasses.so"
    
    for stage in ${toString (lib.concatStringsSep " " (builtins.attrNames profiles.${profile}))}; do
      ${profiles.${profile}.${stage}}/bin/${"stage-${profile}-${stage}"}
    done
    
    echo "Pipeline complete. Optimised IR written to optimized.ll"
  '';

in {
  inherit profiles;
  runLightPipeline = pipeline "light";
  runAggressivePipeline = pipeline "aggressive";
  runCustomPipeline = pipeline "custom";
}
