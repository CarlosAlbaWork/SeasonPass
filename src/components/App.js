// src/App.js
import React, { useEffect, useState, Component } from "react";
import "./App.css";
import Navbar from "./NavBar";
import Web3 from "web3";
import Main from "./Main.js";

class App extends Component {
  async UNSAFE_componentWillMount() {
    await this.loadWeb3();
    await this.loadBlockchainData();
  }

  async loadWeb3() {
    if (window.ethereum) {
      window.web3 = new Web3(window.ethereum);
      await window.ethereum.enable();
    } else if (window.web3) {
      window.web3 = new Web3(window.web3.currentProvider);
    } else {
      window.alert("No ethereum Browser detected, you can check Metamask");
    }
  }

  async loadBlockchainData() {
    const web3 = window.web3;
    const account = await web3.eth.getAccounts();
    this.setState({ account: account[0] });
    const networkId = await web3.eth.net.getId();

    /**const seasonPassData = SeasonPass.networks.networkId[networkId];
     * if (seasonPassData) {
      const seasonPass = web3.eth.Contract(
        SeasonPass.abi,
        seasonPassData.address
      );
      this.setState({ seasonPass });
    }
    const ticketManagerData = TicketManager.networks.networkId[networkId];
    if (ticketManagerData) {
      const ticketManager = web3.eth.Contract(
        TicketManager.abi,
        TicketManagerData.address
      );
      this.setState({ ticketManager });
    } */

    this.setState({ loading: false });
  }

  constructor(props) {
    super(props);
    this.state = {
      account: "0x0",
      seasonPassManagers: {},
      ticketManager: {},
      loading: true,
    };
  }

  render() {
    let content;
    {
      this.state.loading
        ? (content = (
            <p id="loader" className="text-center" style={{ margin: "30 px" }}>
              LOADING PLEASE
            </p>
          ))
        : (content = <Main />);
    }
    return (
      <div>
        <Navbar account={this.state.account} />
        <div className="container-fluid mt-5">
          <div className="row">
            <main
              role="main"
              className="col-lg-12 ml-auto mr-auto"
              style={{ maxWidth: "600px", minHeight: "100vm" }}
            >
              <div>{content}</div>
            </main>
          </div>
        </div>
      </div>
    );
  }
}
export default App;

/**
 * const [data, setData] = useState(null);
  const [account, setAccount] = useState(null);

  useEffect(() => {
    async function fetchData() {
      try {
        const result = await contract.someFunction();
        setData(result);
      } catch (error) {
        console.error("Error al interactuar con el contrato:", error);
      }
    }

    if (account) {
      fetchData();
    }
  }, [account]);

  const connectWallet = async () => {
    try {
      await provider.send("eth_requestAccounts", []);
      const signerAddress = await provider.getSigner().getAddress();
      setAccount(signerAddress);
    } catch (error) {
      console.error("Error al conectar la wallet:", error);
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>Mi DApp</h1>
        {!account ? (
          <button onClick={connectWallet}>Conectar Wallet</button>
        ) : (
          <p>Conectado: {account}</p>
        )}
        {data ? <p>Data: {data.toString()}</p> : <p>Cargando...</p>}
      </header>
    </div>
  );
}

 */
