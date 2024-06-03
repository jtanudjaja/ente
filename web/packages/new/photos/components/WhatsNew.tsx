import { Dialog, styled, useMediaQuery } from "@mui/material";
import React from "react";

interface WhatsNewProps {
    /** Invoked by the component when it wants to get closed. */
    onClose: () => void;
}

/**
 * Show a dialog showing a short summary of interesting-for-the-user things in
 * this release of the desktop app.
 */
export const WhatsNew: React.FC<WhatsNewProps> = ({ onClose }) => {
    const fullScreen = useMediaQuery("(max-width: 428px)");

    return (
        <Dialog open={true} fullScreen={fullScreen}>
            <Contents>
                <button onClick={onClose}>Hello</button>
            </Contents>
        </Dialog>
    );
};

const Contents = styled("div")`
    width: 300px;
    height: 300px;
`;
