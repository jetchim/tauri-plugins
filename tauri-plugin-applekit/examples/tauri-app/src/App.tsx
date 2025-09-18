import "./App.css";
import {useEffect} from "react";
import {get, set, set_theme} from "../../../applekit-api";

function App() {

    useEffect(() => {
        get('testkey').then(_ => {
        })

        set("testkey", "testvalue").then(_ => {
            get('testkey').then(_ => {
            })
        });

        setTimeout(() => {
            set_theme("dark").finally();
        }, 5000)
    }, []);

    return (
        <main className="container">
            <h1>Demo of AppletKit Plug</h1>
        </main>
    );
}

export default App;
