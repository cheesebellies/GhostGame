using UnityEngine;

public class PlayerScript : MonoBehaviour
{
    private double timeElapsed = 0.0;
    private int ticks = 0;

    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        Debug.Log("Player loaded.");
    }

    // Update is called once per frame
    void Update()
    {
        ticks += 1;
        timeElapsed += Time.deltaTime;
        if (ticks % 20 == 0)
        {
            Debug.Log("TPS: " + (int)(ticks / timeElapsed));
        }
    }
}
