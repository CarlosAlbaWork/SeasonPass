// src/eth.js
import { ethers } from "ethers";

const provider = new ethers.providers.Web3Provider(window.ethereum);
const signer = provider.getSigner();

const contractAddress = "0xYourContractAddress";
const contractABI = [
  // Tu ABI aquí
];

const contract = new ethers.Contract(contractAddress, contractABI, signer);

export { provider, signer, contract };
