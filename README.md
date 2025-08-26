This CUDA C++ program finds the **Minimum Spanning Tree (MST)** of a graph using a parallel variant of **Borůvka's algorithm**. It's designed to run on a machine with an NVIDIA GPU and the CUDA Toolkit installed. 🚀

-----

### ⚙️ How It Works

The code implements a parallel version of **Borůvka's algorithm** to find the Minimum Spanning Tree (MST) of a given graph. The algorithm operates in phases, iteratively adding edges to the MST until all vertices are connected.

1.  **Graph Representation**: The graph is represented by its edges, stored in three parallel arrays on the GPU: `s` (source vertices), `d` (destination vertices), and `w` (edge weights). An additional array `type` stores edge types.
2.  **Edge Weight Modification**: The `setter` kernel adjusts edge weights based on their `type` (e.g., "dept," "green," "normal"). This is a preliminary step before the main MST calculation.
3.  **Borůvka's Algorithm (Parallelized)**: The core of the program is a `while` loop that continues until the number of connected components (`nc`) becomes 1. Each iteration of the loop consists of several parallel kernels:
      * **`reset_cheapest` and `reset_claim`**: These kernels initialize temporary arrays (`cheapest`, `cheapest2`, `claim`) for each iteration.
      * **`cefev`**: This kernel finds the cheapest edge for each connected component. It uses `atomicMin` to ensure that multiple threads correctly update the minimum weight for a component.
      * **`cefev2`**: This kernel identifies the specific edge ID that corresponds to the cheapest weight found by `cefev`. It uses `atomicExch` to safely store the edge ID.
      * **`mk`**: This is the "merge" or "Kruskal" kernel. It attempts to add the cheapest edge of each component to the MST. It uses a **disjoint-set union (DSU)** data structure with path compression and union by size. **Atomic operations (`atomicCAS`, `atomicAdd`, `atomicExch`)** are used extensively here to prevent race conditions when multiple threads try to modify the same data structures (parent pointers, component sizes) simultaneously.
4.  **Final Result**: After the loop finishes, the total weight of the MST is copied back to the host and printed, modulo `1000000007`.

-----

### 🖥️ Running the Program

To compile and run this program, you'll need the **NVIDIA CUDA Toolkit** installed.

#### **Mac** 🍎

The CUDA Toolkit for macOS has been deprecated. You can't run this code on macOS directly unless you use a virtualization or cloud environment with a CUDA-enabled GPU.

1.  **Install the CUDA Toolkit**: Follow the instructions from the NVIDIA website.
2.  **Open a Terminal**: Navigate to the directory containing `cs24m013.cu`.
3.  **Compile**: Use `nvcc` to compile the code.
    ```sh
    nvcc cs24m013.cu -o mstw_mac
    ```
4.  **Run**:
    ```sh
    ./mstw_mac
    ```

#### **Windows** 🪟

1.  **Install the CUDA Toolkit**: Download and install the CUDA Toolkit for Windows from the NVIDIA developer website. Make sure you also have **Microsoft Visual Studio** installed, as `nvcc` uses its C++ compiler.
2.  **Open a Command Prompt or PowerShell**: Open a terminal with the environment variables for the CUDA Toolkit and Visual Studio set up. The easiest way is to use the **"Developer Command Prompt for VS"** shortcut that comes with Visual Studio.
3.  **Navigate to the file directory**:
    ```sh
    cd C:\path\to\your\code
    ```
4.  **Compile**:
    ```sh
    nvcc cs24m013.cu -o mstw_win.exe
    ```
5.  **Run**:
    ```sh
    ./mstw_win.exe
    ```

#### **Ubuntu/Linux** 🐧

1.  **Install the CUDA Toolkit**:
    ```sh
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
    sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
    wget https://developer.download.nvidia.com/compute/cuda/12.4.1/local_installers/cuda-repo-ubuntu2004-12-4-local_12.4.1-550.54.14-1_amd64.deb
    sudo dpkg -i cuda-repo-ubuntu2004-12-4-local_12.4.1-550.54.14-1_amd64.deb
    sudo cp /var/cuda-repo-ubuntu2004-12-4-local/cuda-*-keyring.gpg /usr/share/keyrings/
    sudo apt-get update
    sudo apt-get -y install cuda-toolkit-12-4
    ```
2.  **Set Environment Variables**: Add CUDA to your `PATH` and `LD_LIBRARY_PATH`. You can add these lines to your `.bashrc` or `.zshrc` file:
    ```sh
    export PATH=/usr/local/cuda-12.4/bin${PATH:+:${PATH}}
    export LD_LIBRARY_PATH=/usr/local/cuda-12.4/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
    ```
3.  **Open a Terminal**: Navigate to the directory containing `cs24m013.cu`.
4.  **Compile**:
    ```sh
    nvcc cs24m013.cu -o mstw_linux
    ```
5.  **Run**:
    ```sh
    ./mstw_linux
    ```

-----

### 📝 Input Format

The program expects graph data from standard input (`stdin`). The format should be:

**Line 1**: `v e` (number of vertices and number of edges)

**Next `e` lines**: `u v w t` (source vertex `u`, destination vertex `v`, weight `w`, and edge type `t`)

**Example**:

```
5 7
0 1 10 normal
0 2 6 green
0 3 5 dept
1 3 15 normal
2 3 4 dept
2 4 8 green
3 4 9 normal
```

This input describes a graph with 5 vertices and 7 edges.
