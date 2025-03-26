import { useScaffoldContractWrite } from "../../scaffold-eth";
import { useScaffoldContractRead } from "../../scaffold-eth";
import { parseEther } from "viem";

export const useFundManager = () => {
  const { data: feeAmount } = useScaffoldContractRead({
    contractName: "FundManager",
    functionName: "getFeeAmount",
  });

  const { writeAsync: depositFunds } = useScaffoldContractWrite({
    contractName: "FundManager",
    functionName: "depositFunds",
  });

  const handlePayment = async (paymentType: string, amount: bigint) => {
    if (paymentType === "crypto") {
      await depositFunds({
        args: [parseEther(amount.toString())],
      });
    }
    // Handle other payment types...
  };

  return {
    feeAmount,
    handlePayment,
  };
};
